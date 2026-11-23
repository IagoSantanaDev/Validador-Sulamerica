# API intermediária do Validador

Backend Dart com Shelf entre o app Flutter Web e o portal de elegibilidade.
O app envia somente o identificador do prestador; as credenciais e cookies
permanecem no processo backend.

## Executar localmente

Requisito: Dart 3.3 ou superior.

```powershell
Push-Location backend
dart pub get
dart run bin/server.dart
Pop-Location
```

O servidor usa `HOST` (padrão `0.0.0.0`) e `PORT` (padrão `8080`).
`CORS_ORIGIN` aceita uma lista de origens separadas por vírgula. Em produção,
o `render.yaml` configura os frontends públicos no GitHub Pages e Cloudflare
Pages; ao implantar por outro serviço, configure a allowlist no ambiente de
execução. CORS não autentica chamadas diretas.
`PORTAL_MAX_SESSIONS_PER_IDENTIFIER` define sessões máximas do portal por
identificador (padrão 4, faixa 1–8); alteração exige reiniciar o serviço.
`PORTAL_REQUEST_MAX_CONCURRENCY` define concorrência global de chamadas ao
portal e do agendador (padrão 16, faixa 1–20); ambos usam o mesmo limite.

As credenciais são resolvidas exclusivamente no servidor por variáveis no
formato `PORTAL_PRESTADOR_ID_<IDENTIFICADOR>_{CODE,USER,SENHA}`. Cadastre os
valores no ambiente de execução, nunca no repositório ou no app.

## Contrato HTTP

Erros usam `{"status":"erro","mensagem":"..."}`. O corpo JSON máximo é 1 MB.
O payload é validado antes do token.

### Criar sessão lógica

`POST /api/sessoes` é público por identificador e garante uma sessão do portal
autenticada no pool.

```json
{"identificadorPrestador":"<identificador>"}
```

- `201`: `{ "token": "<32 hex>", "identificadorPrestador": "..." }`
- `400`: identificador ausente ou vazio.
- `401`: identificador desconhecido ou credencial recusada.
- `429`: limite local de taxa ou capacidade, sem `Retry-After`.
- `503`: bloqueio global do portal, com `Retry-After` e um objeto `bloqueio`
  contendo `ativo`, `motivo`, `codigo`, `mensagem` e `retryAfterSegundos`.
- `500` ou `502`: falha interna ou resposta inesperada, sem detalhe interno.

### Criar lote

`POST /api/lotes` requer `Authorization: Bearer <token>` e
`Idempotency-Key: <chave única>`.

```json
{
  "consultas": [
    {"tipo":"elegibilidade","chave":"<carteira>"},
    {"tipo":"senha","chave":"<senha>"}
  ]
}
```

`202 Accepted` devolve `id`, `estado` e `total`, com `Location` apontando para
`/api/lotes/{id}/eventos`. Repetir a chave com o mesmo payload retorna a
execução existente; payload diferente retorna `409`. Limite acima de 300 itens
retorna `413`; capacidade esgotada retorna `429` sem `Retry-After`.
Submissões novas retornam `503` com o bloqueio ativo; um replay idempotente
válido continua retornando a execução original.

### Acompanhar execução

`GET /api/lotes/{id}/eventos` requer o mesmo Bearer. É um stream
`text/event-stream`; progresso e resultado são enviados como eventos `progresso`
e `resultado`. O cancelamento global envia `erro` com o objeto `bloqueio`, sem
entregar resultados parciais. A conexão pode retomar eventos enquanto o lote
está ativo ou cancelado por bloqueio usando `desde` ou `Last-Event-ID`. Há no
máximo um stream ativo por lote e o heartbeat é enviado a cada 15 segundos. O
frontend tenta reconectar até três vezes em interrupções de transporte,
aguardando 2, 4 e 8 segundos e retomando do último id recebido. Execuções
canceladas ficam retidas por cinco minutos para replay idempotente e SSE.

`401` indica token inválido; `404` indica lote inexistente, descartado ou de
outro token. Sem assinantes por 30 segundos, o lote é cancelado. Cancelar uma
requisição local não garante que o portal interrompa uma operação já recebida.
O resultado usa `status: "ok"` quando todas as consultas terminaram e
`status: "parcial"` quando há itens pendentes. Resultados concluídos permanecem
em `resultados`; `pendentes` informa `tipo`, `chave` e `motivo`. O limite de
despacho é cinco minutos a partir do enfileiramento: ele impede iniciar novos
itens, mas chamadas em andamento e seus retries podem terminar depois desse
limite.

### Estado do serviço

`GET /api/status` não exige token e fica fora dos limites de requisições ao
portal. Devolve `status`, `portalSulAmerica`, `bloqueio` e `timestamp`:

```json
{
  "status": "ok",
  "portalSulAmerica": {"alcançavel": true, "status": 200},
  "bloqueio": {"ativo": false},
  "timestamp": "2026-11-22T10:00:00.000Z"
}
```

Com bloqueio ativo, `bloqueio` também informa o motivo, código curto, mensagem
e segundos restantes. Enquanto bloqueado, o endpoint não sonda o portal; ao
terminar o cooldown, faz uma sonda exclusiva para decidir se libera consultas.
Não publica sessões, lotes, memória, contadores de falha, tokens,
identificadores, carteirinhas, senhas, cookies, corpos de resposta ou Support
IDs. Métricas operacionais detalhadas podem continuar registradas internamente,
mas não são expostas neste endpoint público.

### Bloqueio global do portal

A primeira falha elegível abre bloqueio para todos os prestadores e cancela
consultas em andamento e lotes na fila. O bloqueio cobre HTTP 429, rejeição F5,
HTTP 408/5xx, falha de rede ou timeout, 401/403 que persistem após renovação de
sessão e respostas inesperadas do portal. Falhas de credenciais, rejeições
locais da API, HTTP 404, erros de negócio e cancelamentos não abrem o bloqueio.

O cooldown escala em 1, 3, 10 e 15 minutos, com limite de 15 minutos. Um
`Retry-After` do portal só prolonga o cooldown quando for maior que o nível
atual. Uma sonda bem-sucedida ao fim do cooldown libera novas consultas; um
sucesso real de consulta ou 15 minutos sem bloqueio reinicia a escala. O
frontend mostra a causa e a contagem regressiva, desabilita o envio e, ao abrir
o bloqueio durante um lote, volta à tela inicial e descarta seus resultados.
Após a liberação, o usuário precisa selecionar e enviar o XML novamente.

## Capacidade e execução

- Uma instância, com estado apenas em memória; reinício encerra sessões e lotes.
- Até 4 sessões do portal por identificador por padrão, limite configurável por
  `PORTAL_MAX_SESSIONS_PER_IDENTIFIER`; máximo documentado de 8 no processo.
- Até 24 execuções na fila e em processamento; a 25ª é rejeitada.
- Até 2 logins simultâneos no processo por padrão; configure
  `PORTAL_LOGIN_MAX_CONCORRENCIA` entre 1 e 16.
- Até 16 requisições simultâneas ao portal por padrão; configure
  `PORTAL_REQUEST_MAX_CONCURRENCY` entre 1 e 20 para ajustar semáforo e
  agendador juntos.
- Uma elegibilidade por sessão; até 3 consultas de senha simultâneas por
  sessão.
- Rate limit de 20/min por identificador em `/api/sessoes`, 20/min por token em
  `/api/lotes` e backstop de 120/min. Status e SSE não consomem esse limite.
- No máximo 200 tokens válidos. O TTL ocioso é de 12 horas após atividade
  autenticada e encerramento de execuções/streams vinculados.

O agendador alterna entre identificadores e lotes, seleciona primeiro uma
sessão autenticada menos ocupada e não abre sessões extras para cada lote.
Resultados de consulta são tipados por chamada. Uma rejeição de sessão (401/403)
pode provocar uma renovação compartilhada e uma repetição. O primeiro erro
elegível abre o bloqueio antes de qualquer retry do item e cancela todos os
lotes; chamadas diretas do harness E2 mantêm o retry interno de
`SessaoPortal`. Rejeições HTTP não são tratadas como falhas de rede.
Configure `PORTAL_RETRY_MAX_TENTATIVAS` (padrão 3),
`PORTAL_RETRY_BACKOFF_BASE_MS` (1000), `PORTAL_RETRY_BACKOFF_MAX_MS` (20000) e
`PORTAL_RETRY_JITTER_PERCENT` (30) no ambiente do backend.
Em 401 na submissão ou no SSE, o frontend cria uma sessão uma vez; na submissão,
mantém a mesma chave idempotente, e no SSE, o último id recebido. Erros 503 com
`bloqueio.ativo` não são repetidos: o lote é descartado e o usuário retorna à
tela inicial. Rejeições HTTP diferentes não são repetidas automaticamente.
Falhas de rede não têm SLA numérico definido: o harness registra duração p50 e
p95 para caracterizar o comportamento medido.

## Segurança e operação

A API não tem autenticação individual nesta entrega: qualquer caller que
conheça um identificador pode solicitar uma sessão lógica. A allowlist CORS
afeta navegadores, não é uma barreira de autenticação ou confidencialidade.
Rate limits e limites de capacidade são controles compensatórios.

Tokens trafegam somente no header Authorization. Não registre credenciais,
tokens, identificadores, carteiras ou senhas. O processo não usa banco nem
estado compartilhado; não habilite réplicas horizontais. O TLS do cliente do
portal mantém a validação padrão de CA e hostname.

O deployment usa `render.yaml` e `backend/Dockerfile`. Configure CORS e
credenciais no ambiente hospedado, sem gravar seus valores em arquivos
versionados. Uma reinicialização invalida as sessões; o frontend solicita uma
nova sessão.

## Testes e carga

```powershell
Push-Location backend
dart analyze
dart test
$simulador = Join-Path $env:TEMP 'simular_carga.exe'
dart compile exe tool/simular_carga.dart -o $simulador
if ($LASTEXITCODE -eq 0) { & $simulador }
$codigo = $LASTEXITCODE
if (Test-Path -LiteralPath $simulador) { Remove-Item -LiteralPath $simulador }
Pop-Location
if ($codigo -ne 0) { throw "A validação do harness AOT falhou." }
```

O harness de carga usa sessões falsas sem rede ou credenciais reais e emite
relatório JSON com conclusão, rejeições, duração p50/p95 e RSS. Execute-o
compilado em AOT para aproximar o modo do servidor de produção; `dart run`
inclui o runtime JIT e não representa essa medição. Na validação local em
Windows, os dois cenários concluíram 12 lotes sem 429 e mediram RSS de
61,6–67,7 MB. `ProcessInfo.currentRss` depende da plataforma, portanto esse
resultado não certifica o RSS no Linux/Render. Não há SLA numérico de duração
antes de medir o comportamento observado no portal real.

O cenário E2 conecta diretamente ao portal, sem passar pelo pool da API. Ele
exige `PORTAL_PRESTADOR_ID_<CNPJ>_{CODE,USER,SENHA}` no ambiente do processo.
Para cada braço (2 e 4 logins), consulta a primeira sessão antes e depois dos
logins adicionais, sem renovação automática durante a sonda; assim 401/403 da
sessão original ficam observáveis. O relatório não inclui carteiras ou senhas.

```powershell
dart run tool/matriz_carga.dart --xml "caminho/arquivo.xml" --cenario e2
```
