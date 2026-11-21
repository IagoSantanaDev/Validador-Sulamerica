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
- `429`: limite de taxa ou capacidade; somente a rejeição por taxa pode trazer
  `Retry-After`.
- `503`: disjuntor do portal aberto ou sonda de recuperação ainda indisponível;
  inclui `Retry-After`.
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
retorna `413`; capacidade esgotada retorna `429` com `Retry-After: 10`.
Submissões novas retornam `503` com `Retry-After` enquanto o disjuntor estiver
aberto ou ocupado pela sonda; um replay idempotente válido continua retornando
a execução original.

### Acompanhar execução

`GET /api/lotes/{id}/eventos` requer o mesmo Bearer. É um stream
`text/event-stream`; progresso e resultado são enviados como eventos `progresso`
e `resultado`. A conexão pode retomar eventos enquanto o lote está ativo usando
`desde` ou `Last-Event-ID`. Há no máximo um stream ativo por lote e o heartbeat
é enviado a cada 15 segundos. O frontend tenta reconectar até três vezes,
aguardando 2, 4 e 8 segundos e retomando do último id recebido. O resultado não
é retido após a execução.

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
portal. Devolve contadores agregados de sessões, lotes, memória RSS, rejeições
429 e falhas upstream, além do resultado da sonda do portal. Não publica nem
retém Support IDs individuais; mantém apenas o contador agregado
`assinaturaF5MarkerSupportId`. `diagnosticoSessaoPortal`
conta rejeições 401/403 antes e depois da renovação, renovações bem-sucedidas,
falhas por motivo e exceções internas. Também registra status HTTP por etapa do
login, redirect sem `Location`, login sem indicador de sessão, status da chamada
AJAX, classe do `Content-Type` e resultado do parse JSON. `concorrenciaPortal`
mostra limites e picos do semáforo de requisições e do pool. O objeto
`concorrenciaPortal.logins` publica `limite`, `ativasAgora`, `picoAtivas`,
`aguardandoAgora`, `picoAguardando` e `totalAguardas`. Contadores de sessões
descartadas após falha inicial de login são preservados. Métricas agregam em
memória e zeram quando o processo reinicia. Não inclui corpo de resposta,
cookies, tokens, identificadores nem dados de consulta.
`disjuntorPortal` expõe estado, sequência de falhas elegíveis, janela, cooldown
e `Retry-After`; `lotes.parciais` conta finalizações parciais. O circuito é
global e em memória: abre após cinco falhas elegíveis consecutivas em 60
segundos (transporte sem resposta ou HTTP 502/503/504), permanece aberto por 60
segundos e exige uma sonda HTTP para fechar. HTTP 429, demais 4xx/5xx,
respostas F5 e falhas de parse não incrementam o contador.
`falhasConsulta` agrega apenas falhas terminais de itens por categoria e status.
Em `diagnosticoSessaoPortal`, contadores `consultaDio...` registram o tipo de
`DioException`, seu tipo de causa interna e o status (ou a ausência dele) para
cada tentativa; `consultaHttp...` registra respostas HTTP não-200. Esses dados
não incluem mensagem de exceção, URL, corpo ou identificadores.

## Capacidade e execução

- Uma instância, com estado apenas em memória; reinício encerra sessões e lotes.
- Até 4 sessões do portal por identificador e no máximo 8 no processo.
- Até 24 execuções na fila e em processamento; a 25ª é rejeitada.
- Até 2 logins simultâneos no processo por padrão; configure
  `PORTAL_LOGIN_MAX_CONCORRENCIA` entre 1 e 16.
- Até 16 requisições simultâneas ao portal.
- Elegibilidade serial por sessão; até 3 consultas de senha concorrentes por
  sessão.
- Rate limit de 20/min por identificador em `/api/sessoes`, 20/min por token em
  `/api/lotes` e backstop de 120/min. Status e SSE não consomem esse limite.
- No máximo 200 tokens válidos. O TTL ocioso é de 12 horas após atividade
  autenticada e encerramento de execuções/streams vinculados.

O agendador alterna entre identificadores e lotes, seleciona primeiro uma
sessão autenticada menos ocupada e não abre sessões extras para cada lote.
Resultados de consulta são tipados por chamada. Uma rejeição de sessão (401/403)
pode provocar uma renovação compartilhada e uma repetição. Falhas de transporte
e respostas HTTP 408, 500, 502, 503 ou 504 recebem até quatro tentativas totais
por item no agendador, com backoff exponencial e jitter. Os retries são
coordenados com o disjuntor; chamadas diretas do harness E2 mantêm o retry
interno de `SessaoPortal`. HTTP 429, 401/403 após renovação e respostas
inesperadas não são repetidas automaticamente. Rejeições HTTP não são tratadas
como falhas de rede.
Configure `PORTAL_RETRY_MAX_TENTATIVAS` (padrão 3),
`PORTAL_RETRY_BACKOFF_BASE_MS` (1000), `PORTAL_RETRY_BACKOFF_MAX_MS` (20000) e
`PORTAL_RETRY_JITTER_PERCENT` (30) no ambiente do backend.
`GET /api/status` publica os valores efetivos em `resilienciaPortal.retryConfiguracao`
e, em `resilienciaPortal.retriesAgendador`, os contadores `iniciados`,
`resolvidos` e `esgotados`. Um retry é contado como iniciado depois do backoff
e da permissão do disjuntor; cancelamentos durante o backoff não são contados.
`resolvidos` conta itens que tiveram sucesso após retry. `esgotados` conta
somente itens cuja última tentativa permitida também falhou de forma retryable;
uma cadeia que termina em falha não retryable não incrementa esse contador.

Em 401 na submissão ou no SSE, o frontend cria uma sessão uma vez; na submissão,
mantém a mesma chave idempotente, e no SSE, o último id recebido. Na criação de
sessão, 429 e 503 só são repetidos uma vez se houver `Retry-After`. Para criação
de lote, 429 e 503 permitem até três reenvios com a mesma chave e backoff de 1, 2 e 4
segundos; um `Retry-After` substitui a espera correspondente e é limitado a 60
segundos. Rejeições HTTP diferentes não são repetidas automaticamente. Falhas de rede
não têm SLA numérico definido: o harness registra duração p50 e p95 para
caracterizar o comportamento medido.

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
