# PRD — Backend para 12 usuários simultâneos no Render free

## 1. Contexto

O backend em `backend/` é um proxy Dart (shelf) entre o Flutter Web e o portal
SulAmérica. Ele roda em uma única instância no Render free (0,1 CPU / 512 MB) e
mantém as sessões do portal em memória. Hoje, com ~12 colaboradores usando o
site ao mesmo tempo, os resultados do validador são comprometidos.

### Causas raiz identificadas no código atual

1. `_loteEmAndamento` em `backend/lib/validador_api.dart` permite **um único
   lote no processo inteiro**. Enquanto um usuário processa, todos os outros
   recebem `429 Ja existe um lote em andamento`.
2. O rate limit usa o IP da conexão real. No Render o TLS termina no proxy, então
   todos os usuários compartilham o mesmo endereço e o mesmo balde de 40 req/min.
3. `_limiteSessoes = 10` para 12 usuários. Cada login evicta a sessão de outro
   usuário, que recebe 401 no próximo lote e precisa reautenticar.
4. Lotes com 10+ elegibilidades abrem até 9 sessões extras (2 requests de login
   cada) por lote, aumentando CPU, memória e risco de bloqueio no portal.
5. O front usa `receiveTimeout` de 30 s. Fila longa dentro da requisição síncrona
   estoura o timeout e duplica trabalho no portal.

### Restrições

- Render free é obrigatório: 0,1 CPU, 512 MB, instância única.
- A sessão do portal vive em memória; não há réplica nem estado compartilhado.
- O front pode mudar de forma ampla, com deploy coordenado.
- O cenário tem 12 pessoas, exatamente dois identificadores de prestador e um
  trio de credenciais por identificador. As pessoas compartilham esses acessos.
- Credenciais continuam resolvidas no servidor, **um trio `code/user/senha` por
  identificador**. O front continua enviando apenas o identificador.
- A API continua pública e sem autenticação individual nesta entrega; o risco
  de chamadas diretas por terceiros que conheçam um identificador é aceito.
- Nenhum segredo, token ou chave pode ir para log, URL ou repositório.

## 2. Objetivos

- Suportar 12 usuários simultâneos sem perda de resultados por 429 global.
- Eliminar o limite de um lote por processo.
- Eliminar o balde único de rate limit.
- Reaproveitar sessões do portal em vez de abrir uma por login/lote.
- Manter o processo confortavelmente abaixo de 512 MB.
- Preservar as regras de negócio atuais (carteira, senha, elegibilidade).
- Proteger operações de sessão lógica com `Authorization: Bearer`; a criação
  de sessão permanece pública por identificador, conforme risco aceito.

### Não objetivos

- Réplica horizontal, persistência em banco ou estado compartilhado.
- Retomar lote depois de recarregar a página.
- Autenticação individual, SSO ou autorização por pessoa usuária.
- Manter `/api/login` e `/api/consultas` durante a transição.
- Trocar o portal, o fluxo de credenciais ou as regras de elegibilidade.
- Implementar fallback de polling para o SSE nesta entrega.

## 3. Métricas de sucesso

| Métrica | Alvo |
|---|---|
| 12 lotes de 300 itens submetidos juntos | todos concluem; a 25ª execução recebe 429 quando as 24 vagas totais estão ocupadas |
| Logins no portal por lote | 0 (pool já aquecido) |
| Sessões do portal no processo | ≤ 8 (4 por identificador) |
| Memória RSS no harness local | < 200 MB |
| Retenção de resultado após o fim | 0 (descartado) |
| Requisições síncronas > 30 s | 0 (SSE não conta) |
| Rate limit | por token em `/api/lotes`; por identificador em `/api/sessoes` |
| Tempo de processamento | Sem SLA numérico antes do harness; registrar p50 e p95 |

## 4. Arquitetura alvo

```
Flutter Web                         Backend (1 instância)                Portal
-----------                         ---------------------                ------
POST /api/sessoes  ------------>  RepositorioSessoes (token -> id)
                                   PoolSessoesPortal[identificador]
                                     └─ 4 SessaoPortal (login tardio)
POST /api/lotes    ------------>  AgendadorLotes (24 execuções totais)
                                     └─ workers por sessão
GET  /api/lotes/{id}/eventos --->  ExecucaoLote (progresso + resultado)
       (SSE via fetch; máximo de 1 stream por lote)
GET  /api/status   ------------>  contadores + sonda do portal
```

### Componentes

| Componente | Responsabilidade |
|---|---|
| `RepositorioSessoes` | tokens opacos, identificador associado, idempotência |
| `PoolSessoesPortal` | 4 sessões por identificador, login tardio, renovação |
| `AgendadorLotes` | limite total de 24 execuções, justiça por identificador e lote, workers, cancelamento |
| `ExecucaoLote` | estado, progresso, resultados, buffer de eventos, assinantes |
| `SseLote` | codificação `text/event-stream`, heartbeat, replay `desde` |
| `ValidadorApi` | rotas, validação de payload, Bearer, CORS, rate limit |

### Regras de concorrência

- Elegibilidade é serial **por sessão** (o form do portal tem estado).
- Senhas rodam até 3 em paralelo **por sessão**.
- Semáforo global de requisições ao portal: 16.
- Justiça: rodízio entre identificadores e, dentro de cada identificador,
  entre lotes; muitos lotes de um prestador não monopolizam o portal.
- Capacidade: máximo de 24 execuções no total, incluindo processamento e fila;
  a 25ª recebe 429.
- Falha de sessão (401/403): renovar login e repetir a consulta uma vez.
  Consultas que observaram a mesma geração da sessão compartilham o resultado
  da renovação, seja sucesso ou falha; uma consulta posterior pode tentar nova
  renovação.
- Falha transitória de rede em consulta: aguardar 500 ms e repetir uma vez.
  O orçamento é por categoria: no máximo uma repetição por falha de sessão e
  uma por falha de rede, até 3 tentativas de consulta no total.
- Login feito durante renovação tem seu próprio retry de rede após 500 ms, uma
  vez; se ainda falhar, todas as consultas da mesma geração recebem a falha.
- Cancelamento de execução remove itens pendentes e cancela chamadas Dio ativas
  com token próprio da execução; chamadas canceladas não são repetidas. O
  cancelamento local não garante que o portal interrompa uma operação já
  recebida.
- Falha de formato: erro no item, sem tocar o portal.

## 5. Contrato HTTP

Todas as respostas de erro mantêm `{"status": "erro", "mensagem": "..."}`.

### 5.1 `POST /api/sessoes`

Cria uma sessão lógica (token) e garante que o pool do identificador tem pelo
menos uma sessão do portal autenticada.

```http
POST /api/sessoes
Content-Type: application/json

{"identificadorPrestador": "<identificador-redigido>"}
```

- `201 Created`: `{"token": "<32 hex>", "identificadorPrestador": "..."}`
- `400`: identificador ausente/vazio.
- `401`: identificador desconhecido ou credencial recusada.
- `500`: falha interna do backend, sem detalhe interno na resposta.
- `502`: resposta inválida ou inesperada do portal.
- `503`: portal indisponível ou falha de rede.
- `429`: limite de criação de sessões por taxa ou por capacidade. Expurgar
  tokens expirados antes de verificar o teto de 200; não remover tokens ainda
  válidos para abrir espaço. A resposta de limite de capacidade não inclui
  `Retry-After`; o front só repete criação uma vez quando esse header estiver
  presente.

### 5.2 `POST /api/lotes`

```http
POST /api/lotes
Authorization: Bearer <token>
Idempotency-Key: <uuid/hex gerado pelo front>
Content-Type: application/json

{"consultas": [{"tipo": "elegibilidade", "chave": "..."}, {"tipo": "senha", "chave": "..."}]}
```

- `202 Accepted`
  - `Location: /api/lotes/{id}/eventos`
  - `{"id": "<id>", "estado": "na_fila", "total": 300}`
- `400`: payload inválido (mesmas regras atuais por item).
- `401`: token ausente/inválido.
- `413`: mais de 300 itens ou corpo acima de 1 MB.
- `429`: fila cheia; inclui `Retry-After: 10`.
- `409`: mesma `Idempotency-Key` com payload diferente.
- Repetição com a mesma chave e mesmo payload devolve o mesmo `202` e o mesmo
  `id` enquanto a execução existir, sem duplicar trabalho no portal. Depois do
  fim (sem retenção), a mesma chave cria uma nova execução. Retry tardio pode
  repetir consultas no portal; esse risco é aceito para não reter resultados.

### 5.3 `GET /api/lotes/{id}/eventos`

```http
GET /api/lotes/{id}/eventos?desde=12
Authorization: Bearer <token>
Accept: text/event-stream
```

- `200` com `Content-Type: text/event-stream; charset=utf-8`,
  `Cache-Control: no-cache`, `X-Accel-Buffering: no`, `Connection: keep-alive`.
- `401`: token inválido.
- `404`: lote inexistente, já descartado ou de outro token.
- No máximo um stream ativo por lote; nova conexão encerra e substitui a
  anterior. Reconexão usa o último id recebido enquanto a execução existir.
- Eventos:

```text
id: 12
event: progresso
data: {"concluidas": 120, "total": 300}
```

```text
id: 300
event: resultado
data: {"status": "ok", "resultados": [ ... ]}
```

```text
event: erro
data: {"mensagem": "..."}
```

- `: ping` a cada 15 s.
- `retry: 3000` no início do stream.
- `desde` (ou `Last-Event-ID`) replica eventos a partir do id informado,
  **somente enquanto o lote está ativo**.
- O resultado final é descartado depois de entregue; não há retenção.
- Sem assinantes por 30 s: o lote é cancelado, itens pendentes são removidos e
  as chamadas Dio ativas são canceladas; esse cancelamento não garante que o
  portal pare o processamento que já recebeu. Chamadas canceladas não entram
  na política de retry.
- `GET /api/lotes/*/eventos` não usa rate limit de portal; o limite de um
  stream ativo por lote restringe conexões simultâneas.

### 5.4 `GET /api/status`

Mantém o health check fora do rate limit. Passa a devolver contadores:

```json
{
  "status": "ok",
  "sessoesAtivas": 3,
  "lotes": {"ativos": 2, "naFila": 1, "concluidos": 17},
  "memoriaRssMb": 42,
  "rateLimit": {"rejeicoes429": 0},
  "falhasPortal": {"502": 0, "503": 0},
  "portalSulAmerica": {"alcançavel": true, "status": 200},
  "timestamp": "..."
}
```

Os contadores são agregados e não incluem token, identificador, carteira ou
senha. Alertas operacionais são configurados pelo operador fora do código.

### 5.5 Rotas removidas

`POST /api/login` e `POST /api/consultas` são removidas no mesmo deploy do front.

## 6. Modelo de domínio e estados

- **Prestador**: CNPJ que identifica a conta no portal.
- **Identificador de prestador**: valor enviado pelo front; resolve um trio de
  credenciais no servidor.
- **Sessão do portal**: `SessaoPortal` autenticada no portal, com cookies.
- **Sessão lógica**: token opaco emitido ao front; não guarda cookies.
- **Lote**: payload de consultas enviado pelo front.
- **Execução**: estado no servidor de um lote (fila, processamento, fim).
- **Consulta**: item de um lote (`elegibilidade` ou `senha`).

Estados da execução:

```
na_fila -> processando -> concluido
                      \-> falhou
                      \-> cancelado
```

Invariantes:

- Um token pertence a exatamente um identificador.
- Uma execução pertence a exatamente um token.
- Resultado só é entregue ao dono do token.
- Token com stream ou execução ativos não expira; após a última atividade
  autenticada e o fim de todos os vínculos ativos, começa o TTL ocioso.
- Nenhuma sessão do portal é encerrada no meio de uma consulta.
- O processo não retém resultado depois do fim.

## 7. Capacidade e memória

| Item | Valor |
|---|---|
| Sessões do portal | 4 por identificador, 8 no total |
| Requisições simultâneas ao portal | 16 |
| Execuções processando + aguardando | 24 no total; a 25ª recebe 429 |
| Itens por lote | 300 |
| Corpo máximo | 1 MB |
| Heartbeat SSE | 15 s |
| Carência de cancelamento | 30 s |
| Retenção após o fim | nenhuma |
| Tokens | máx. 200 válidos; TTL deslizante de 12 h após última atividade autenticada e fim de streams/execuções ativos |
| Sessões ociosas do portal | sem TTL; teto fixo de 8 |

Memória estimada: ~30 MB de base AOT + 8 sessões + até 24 execuções ativas
(resultados ~30 KB cada) + buffers de eventos (~50 KB por lote ativo). Muito
abaixo de 512 MB.

## 8. Segurança

- Token em `Authorization: Bearer`, nunca em URL, corpo ou log.
- Token gerado com `Random.secure()` (16 bytes).
- Lote só é acessível pelo token que o criou.
- `Idempotency-Key` é escopada ao token.
- Rate limit de 20/min por token em `/api/lotes`, 20/min por identificador em
  `/api/sessoes` e backstop global de 120/min. `/api/status` e `/eventos` ficam
  fora do rate limit de portal.
- CORS permite `Authorization`, `Idempotency-Key` e `Last-Event-ID`; expõe
  `Location`; produção usa a allowlist já configurada no Render, sem copiar
  valores de origem para esta documentação.
- CORS não autentica chamadas diretas. `POST /api/sessoes` permanece público;
  qualquer caller que conheça identificador pode obter token e consultar o
  portal. Risco aceito nesta entrega, sem garantia de confidencialidade.
- Mitigações compensatórias: allowlist de origens no browser, rate limits,
  limite de 24 execuções, um stream por lote e alertas operacionais.
- Logs estruturados não imprimem credenciais, tokens, identificadores,
  carteiras ou senhas. `/api/status` expõe somente contadores agregados.
- Nenhuma nova variável de ambiente nem fornecedor de telemetria; alertas são
  configurados pelo operador fora do código.

## 9. Plano de tarefas em worktrees

Regras gerais:

- Cada tarefa roda em **worktree isolada**, criada a partir de `main` já com as
  ondas anteriores mergeadas.
- Orçamento: **≤ 500 linhas úteis por worktree**. Linhas em branco, comentários
  e testes não contam.
- Se uma tarefa estourar o orçamento, ela é dividida antes do merge.
- Testes da tarefa entram no mesmo worktree, mas não contam no orçamento.
- Subagente não altera arquivos fora da lista da tarefa.
- O orquestrador valida, mergeia e dá push após cada tarefa.

### Medição do orçamento

```powershell
git diff --unified=0 main...HEAD -- "*.dart" ":(exclude)backend/test/**" ":(exclude)test/**" |
  Where-Object { $_ -match '^\+' -and $_ -notmatch '^\+\+\+' } |
  Where-Object { $_.Substring(1).Trim() -notmatch '^(//|/\*|\*|\*/|$)' } |
  Measure-Object -Line
```

O número é aproximado; o revisor confirma no diff. Testes, comentários e linhas
em branco não entram na conta.

### Visão geral

| ID | Tarefa | Depende de | Wave | Orçamento | Estado |
|---|---|---|---|---|---|
| T1 | Núcleo HTTP (JSON, CORS, Bearer) | — | 1 | 250 | Concluída em `main` (`76ccf8f`) |
| T2 | Rate limit por token/identificador/global | — | 1 | 160 | Concluída em `main` (`f653589`) |
| T3 | Execução de lote + codificação SSE | — | 1 | 380 | Concluída em `main` (`f2c03df`) |
| T7 | Front: cliente SSE + serviço HTTP | contrato | 1 | 450 | Concluída em `main` (`5df2b26`) |
| T4 | Pool de sessões + concorrência do `SessaoPortal` | T3 | 2 | 380 | Implementada localmente; aguardando integração |
| T8 | Front: controller assíncrono | T7 | 2 | 450 | Implementada localmente; aguardando integração |
| T5 | Agendador de lotes | T3, T4 | 3 | 300 | Implementada localmente; aguardando integração |
| T6 | Rotas e wiring final | T1, T2, T3, T4, T5 | 4 | 400 | Implementada localmente; aguardando integração |
| T9 | Harness de carga 12 usuários | T6 | 5 | 220 | Implementada localmente; aguardando integração |
| T10 | Documentação, ADRs e memória | todas | 6 | 0 | Implementada localmente; aguardando integração |

### T1 — Núcleo HTTP (concluída)

**Worktree:** `t1-nucleo-http`

**Arquivos existentes — reutilizar**

- `backend/lib/http/json.dart`: leitura de corpo com limite de 1 MB, respostas
  JSON, erro padronizado, `Retry-After`.
- `backend/lib/http/cors.dart`: middleware atual, com `Authorization`,
  `Idempotency-Key`, `Last-Event-ID`, `Access-Control-Expose-Headers: Location`.
- `backend/lib/http/auth.dart`: extração e validação de `Authorization: Bearer`.

**Testes**

- `backend/test/http/json_test.dart`
- `backend/test/http/cors_test.dart`
- `backend/test/http/auth_test.dart`

**Aceite**

- Testes de corpo inválido, corpo > 1 MB (413), Bearer ausente/malformado (401),
  CORS com lista, wildcard, `Vary: Origin`, preflight e headers permitidos.
- `dart analyze` e `dart test` verdes no pacote `backend/`.

### T2 — Rate limit (concluída)

**Worktree:** `t2-rate-limit`

**Arquivos existentes — reutilizar**

- `backend/lib/http/rate_limit.dart`
- `backend/test/http/rate_limit_test.dart`

**Regras**

- Chave `token:<token>` para `POST /api/lotes`: 20/min.
- Chave `prestador:<identificador>` para `POST /api/sessoes`: 20/min.
- Backstop global: 120/min.
- `GET /api/status` e `GET /api/lotes/*/eventos` isentos.
- Resposta `429` com `Retry-After` em segundos.
- Limpeza de janelas expiradas; mapa não cresce sem limite.

**Aceite**

- Buckets independentes; estouro de um token não bloqueia outro.
- Backstop global funciona.
- `Retry-After` presente e numérico.
- Testes verdes.

### T3 — Execução de lote + SSE (concluída)

**Worktree:** `t3-execucao-sse`

**Arquivos existentes — reutilizar**

- `backend/lib/modules/sulamerica/data/execucao_lote.dart`
- `backend/lib/http/sse.dart`
- `backend/test/execucao_lote_test.dart`
- `backend/test/http/sse_test.dart`

**Responsabilidades**

- Estados `na_fila`, `processando`, `concluido`, `falhou`, `cancelado`.
- Resultados por item e contagem de progresso.
- Buffer de eventos com ids sequenciais e replay `desde`.
- Assinantes SSE; `: ping` a cada 15 s (injetável).
- Cancelamento após 30 s sem assinantes (injetável).
- `descartar()` limpa resultados, buffer e timers.

**Aceite**

- Emissão correta de `id`, `event`, `data`, heartbeat e `retry`.
- Replay a partir de `desde`; ids monotônicos.
- Cancelamento dispara só após a carência.
- Nenhum timer vaza após `descartar()`.
- Testes verdes.

### T4 — Pool de sessões + concorrência do `SessaoPortal`

**Worktree:** `t4-pool-sessoes`

**Arquivos**

- Novo: `backend/lib/modules/sulamerica/data/pool_sessoes_portal.dart`
- Novo: `backend/lib/modules/sulamerica/data/resultado_consulta_portal.dart`
- Editar: `backend/lib/modules/sulamerica/data/sessao_portal.dart`
- Testes: `backend/test/pool_sessoes_portal_test.dart`,
  `backend/test/sessao_portal_*_test.dart`

**Mudanças**

- `consultarBeneficiario` e `consultarSenha` deixam de depender do campo mutável
  `_ultimoStatusFalha`; devolvem resultado tipado por chamada, com `dados` +
  `status` no sucesso ou categoria + `status` na falha.
- Renovação coalescida por geração da sessão: consultas concorrentes que
  observaram a mesma geração compartilham sucesso ou falha; consulta posterior
  pode iniciar nova renovação.
- Consulta repete uma vez após renovar sessão e uma vez após falha transitória
  de rede, em até 3 tentativas. O login de renovação tem um retry de rede
  próprio após 500 ms; falha final é compartilhada pela geração.
- `HttpClient` com `maxConnectionsPerHost: 8` e `idleTimeout: 10s`, mantendo a
  validação de CA/hostname.
- Pool: 4 sessões por identificador, criação tardia, login único por sessão,
  `garantirAutenticada()` para o `POST /api/sessoes`, `executar()` com semáforo.
- Sem sessões extras por lote.

**Aceite**

- Duas consultas concorrentes na mesma sessão não corrompem status nem
  compartilham resultado de outra chamada.
- 401/403 concorrentes na mesma geração compartilham uma renovação e seu
  resultado, inclusive falha; uma consulta posterior pode tentar novamente.
- Consulta repete no máximo uma vez por categoria (sessão e rede); login de
  renovação repete falha transitória de rede uma vez após 500 ms.
- Pool nunca passa de 4 sessões por identificador.
- `POST /api/sessoes` falha com 401 se o login inicial falhar.
- Logins concorrentes em `garantirAutenticada()` resultam em **um** login por
  sessão, não em uma corrida de logins.
- `dart test` verde, incluindo testes existentes de login/TLS.

### T5 — Agendador de lotes

**Worktree:** `t5-agendador`

**Arquivos**

- Novo: `backend/lib/modules/sulamerica/data/agendador_lotes.dart`
- Teste: `backend/test/agendador_lotes_test.dart`

**Responsabilidades**

- Máximo de 24 execuções totais, incluindo as processando e aguardando; a 25ª
  recebe `FilaCheiaException` (vira 429).
- Rodízio entre identificadores e, dentro de cada identificador, entre lotes.
- Workers por sessão: 1 elegibilidade serial, até 3 senhas paralelas.
- Semáforo global de 16 requisições ao portal.
- Atualiza progresso da execução a cada item; emite progresso agregado no máximo
  a cada 500 ms.
- Cancelamento remove itens pendentes e cancela chamadas Dio em andamento com
  `CancelToken` próprio da execução, sem cancelar chamadas de outros lotes que
  compartilham a sessão. Cancelamento não dispara retry e não garante que o
  portal interrompa operação já recebida.

**Aceite**

- 12 lotes de 300 itens progridem juntos; nenhum termina antes dos demais por
  monopolização.
- Fila cheia devolve erro específico.
- Cancelar libera a fila, não executa itens pendentes e cancela chamadas ativas
  sem fechar a sessão do portal nem repetir chamadas canceladas.
- Cancelar uma execução não cancela chamadas concorrentes de outra execução
  que compartilhe a mesma sessão.
- Testes verdes.

### T6 — Rotas e wiring

**Worktree:** `t6-rotas`

**Arquivos**

- Reescrever: `backend/lib/validador_api.dart`
- Novo: `backend/lib/modules/sulamerica/data/repositorio_sessoes.dart`
- Editar: `backend/bin/server.dart` (logger simples, sem pretty printer)
- Reescrever: `backend/test/validador_api_test.dart`
- Remover/ajustar testes das rotas antigas

**Mudanças**

- `POST /api/sessoes`, `POST /api/lotes`, `GET /api/lotes/{id}/eventos`,
  `GET /api/status`; remover `/api/login` e `/api/consultas`.
- `POST /api/sessoes` é público; não existe identidade individual nesta entrega.
- Validar payload antes do token, como hoje.
- Idempotência por token + chave; 409 para payload diferente.
- Uma conexão SSE ativa por lote; nova conexão fecha e substitui a anterior.
- SSE com `Response` stream, `context['shelf.io.buffer_output'] = false`.
- `RepositorioSessoes`: até 200 tokens válidos, dono do lote e idempotência;
  expurga expirados antes de criar, rejeita com 429 sem eviction se ainda
  estiver cheio. TTL deslizante de 12 h, renovado por uso autenticado; stream
  ou execução ativos pinam o token e o TTL começa após o último vínculo acabar.
- `/api/status` com contadores e RSS (`ProcessInfo.currentRss`).
- Contadores agregados incluem rejeições 429 e falhas upstream 502/503, sem
  identificadores ou dados de consulta.
- Logs de produção estruturados em JSON por `LogPrinter` do pacote `logger`
  existente, nível `info`; sem dependência nova.

**Aceite**

- Contrato completo coberto por testes: 201, 202, 400, 401, 404, 409, 413, 429,
  500, 502, 503, SSE, replay, substituição de assinante, cancelamento e ownership.
- Testes cobrem limite de 200 tokens sem eviction, expiração/pin de tokens e
  distinção entre 429 de taxa (com `Retry-After`) e capacidade (sem header).
- Nenhuma referência a `/api/login` ou `/api/consultas` no backend.
- `dart analyze` e `dart test` verdes.

### T7 — Front: cliente SSE + serviço HTTP (concluída)

**Worktree:** `t7-front-sse`

**Arquivos existentes — reutilizar**

- `lib/globals/network/sse_client.dart` (export condicional)
- `lib/globals/network/sse_client_stub.dart`
- `lib/globals/network/sse_client_web.dart` (`package:web` + `fetch` +
  `ReadableStream`)
- `lib/modules/validador_xml/data/models/lote_remoto.dart`
- `lib/modules/validador_xml/data/services/sul_america_backend_service.dart`
- `pubspec.yaml`/`pubspec.lock` já incluem `web`.
- Testes existentes: `test/globals/network/sse_client_test.dart`,
  `test/modules/validador_xml/data/services/sul_america_backend_service_test.dart`

O cliente SSE, modelo e serviço HTTP foram adicionados em `5df2b26`. O serviço
mantém métodos antigos temporários; T8 deve migrar o controller e removê-los.
Não recriar esses arquivos nem introduzir cliente paralelo.

**Mudanças**

- Parser SSE manual: eventos separados por linha em branco, `data` multilinha,
  comentários como heartbeat, `id`, `event`.
- `fetch` com `Authorization`, `Accept: text/event-stream`, `desde`.
- AbortController para cancelar o stream.
- Watchdog de heartbeat (ex.: 45 s sem dados → erro de stream).
- Serviço: `criarSessao`, `criarLote` (com `Idempotency-Key`), `abrirEventos`.
- Token sempre em header; nenhum token no corpo.
- Stub para VM/testes não-web: erro explícito ao tentar SSE fora do web.

**Aceite**

- Parser cobre chunk cortado no meio de um evento, `data` multilinha e heartbeat.
- Serviço envia Bearer e idempotência; mapeia 401/404/429/5xx para as exceções
  existentes.
- `flutter analyze` e `flutter test` verdes; `flutter build web` compila o
  caminho web.

### T8 — Front: controller assíncrono

**Worktree:** `t8-front-controller`

**Arquivos**

- Editar: `lib/modules/validador_xml/presentation/controllers/validador_controller.dart`
- Editar: `lib/modules/validador_xml/presentation/widgets/barra_progresso_envio.dart`
  (se necessário para progresso real)
- Testes existentes: `test/validador_controller_test.dart` e
  `test/validador_controller_consulta_test.dart`

**Mudanças**

- Fluxo: `POST /api/sessoes` → chunks sequenciais de até 300 →
  `POST /api/lotes` → SSE; progresso acumulado por arquivo.
- Progresso real por evento; não usar mais “etapas” fictícias.
- 401: reautenticar uma vez e recriar o lote.
- 429: aguardar `Retry-After`/backoff e tentar de novo; sem duplicar lote.
- Em `POST /api/sessoes`, repetir uma vez somente se 429 trouxer
  `Retry-After`; sem header, exibir a mensagem de limite de capacidade sem
  retry automático.
- Reconectar SSE com esperas de 2 s, 4 s e 8 s, no máximo 3 vezes, usando o
  último id recebido; depois manter itens pendentes para retentativa manual.
- A retentativa manual pode repetir consultas se a execução anterior terminou
  antes da reconexão, pois resultados concluídos não são retidos.
- Sem retomada após recarregar; remover qualquer persistência de lote.
- Manter `_consultasPendentes` e o botão de retentativa para itens que falharam
  no portal.
- Manter limites locais de carteira/senha.

**Aceite**

- 12 lotes simulados via fake do serviço; progresso e resultado aplicados.
- Queda de SSE reconecta até 3 vezes (2/4/8 s); depois itens ficam pendentes.
- 429 em `POST /api/sessoes` com `Retry-After` tenta uma vez; sem header não
  dispara retry automático.
- Recarregar não tenta retomar.
- `flutter test` e `flutter analyze` verdes.

### T9 — Harness de carga

**Worktree:** `t9-carga`

**Arquivos**

- Novo: `backend/tool/simular_carga.dart`
- Novo: `backend/test/carga_test.dart`

**Responsabilidades**

- `SessaoPortal` fake com latência configurável.
- Sobe a API em porta efêmera; 12 clientes enviam 300 itens cada.
- Testa os 12 clientes em um identificador e divididos entre os dois.
- Mede conclusão, 429 por fila, duração p50/p95 e RSS; não há SLA numérico
  antes de medir o comportamento real do portal.
- Não toca o portal real; não usa credenciais.

**Aceite**

- 12 lotes concluem sem 429 com limite de 24 execuções totais.
- O 25º lote recebe 429 com `Retry-After`.
- RSS e duração p50/p95 registrados no relatório do teste.
- Teste não depende de rede.

### T10 — Documentação e memória

**Worktree:** `t10-docs`

**Arquivos**

- `backend/README.md`: contrato novo, SSE, pool, limites, memória, deploy.
- `GLOSSARY.md`: revisar termos contra o código final.
- `docs/adr/0001-lotes-assincronos-com-sse.md`: revisar decisão e consequências.
- `docs/adr/0002-pool-de-sessoes-por-prestador.md`: revisar decisão e consequências.
- `docs/adr/0003-api-publica-com-controles-compensatorios.md`: registrar risco e
  controles compensatórios da API pública.
- `.agents/memoria.md`: causas raiz confirmadas e como evitar regressão (arquivo
  local, não versionado).
- `render.yaml`: comentários atualizados; produção exige allowlist CORS já
  configurada no Render, sem valores de origem ou credenciais na documentação.

**Aceite**

- Nenhum comando, rota ou caminho citado está errado.
- README não menciona rotas removidas.
- ADRs explicam o porquê, não o como.
- Nenhum identificador real, origem específica ou credencial é copiado para
  documentação; CORS allowlist não é apresentada como autenticação.
- `dart test` e `flutter test` continuam verdes.

## 10. Orquestração

1. Criar a worktree da onda com `worktree_create` a partir de `main`.
2. Disparar um subagente `general` por tarefa, em paralelo quando os arquivos
   forem disjuntos, com o prompt abaixo.
3. Aguardar todos os subagentes ficarem ociosos.
4. Validar cada worktree: budget, `dart analyze`, `dart test` (ou `flutter`).
5. Mergear na ordem da tabela; rodar a suíte completa após cada merge.
6. Push após cada merge.
7. Só então criar as worktrees da onda seguinte.

### Prompt padrão para o subagente

```text
Trabalhe exclusivamente em <WORKTREE>.
Leia docs/prd/0001-backend-multiusuario.md, seção <TAREFA>, e
.agents/AGENTS.md.

Escopo: <ARQUIVOS>.
Não altere outros arquivos sem autorização.
Orçamento: ≤ 500 linhas úteis (testes, comentários e linhas em branco não
contam). Rode a medição e reporte o número.

Implemente, escreva os testes da tarefa e rode:
- backend: rode `dart analyze` e `dart test` dentro de `backend/`
- front: rode `flutter analyze` e `flutter test` na raiz

Commit em Conventional Commits pt-BR, uma linha, sem body. Não dê push.
Reporte: resumo, arquivos, linhas úteis, testes executados e riscos.
```

## 11. Testes e validação

### Backend

No PowerShell, a partir da raiz:

```powershell
Push-Location backend
dart analyze
dart test
Pop-Location
```

- Testes novos por componente e integração de rotas.
- Testes existentes de parser, credenciais, TLS e falhas de sessão continuam
  valendo, ajustados apenas onde o contrato mudou.

### Front

Na raiz do projeto:

```powershell
flutter analyze
flutter test
flutter build web --release --dart-define="API_URL=<origem-da-api-redigida>"
```

Substitua o placeholder pela origem configurada antes do build final.

### Manual (após deploy)

1. `GET /api/status` → 200 e contadores.
2. `POST /api/sessoes` com identificador válido → 201.
3. Lote de 1 elegibilidade → SSE com progresso e resultado.
4. Lote de 300 itens → progresso contínuo, sem 429.
5. Recarregar a página no meio → lote é cancelado após 30 s; front não retoma.
6. Dois navegadores em paralelo → tokens e lotes independentes.
7. `/api/status` expõe somente contadores agregados; logs não contêm credenciais,
   tokens, identificadores, carteiras ou senhas.
8. CORS aceita apenas as origens configuradas no Render; chamada direta à API
   continua possível e não é bloqueada por CORS.

## 12. Rollout e rollback

- O contrato quebra: backend e front são implantados na mesma janela.
- Ordem: backend primeiro e front logo em seguida, aceitando uma janela curta de
  erro para quem carregar o front antigo; alternativa é avisar os 12 usuários
  para recarregar a página.
- Rollback: Render → deploy anterior; Cloudflare Pages → deployment anterior.
- Sem migração de dados. A sessão do portal se perde no restart; o front
  reautentica.

## 13. Riscos e mitigações

| Risco | Mitigação |
|---|---|
| Cloudflare/Render bufferizam o SSE | heartbeat 15 s, `X-Accel-Buffering: no`, teste manual; se falhar, próxima entrega adiciona polling |
| Portal limita sessões por credencial | teto de 4 por identificador; monitorar 401/403 e reduzir |
| 0,1 CPU insuficiente para 12 lotes | trabalho é rede; pool e semáforo limitam concorrência; harness mede |
| Deploy quebrado entre backend e front | janela coordenada e rollback documentado |
| Sem retenção/retomada | decisão explícita; front avisa e permite reenviar |
| Token vazando em log | Bearer, nenhum token em URL; revisão de log nos testes |
| API pública sem identidade individual | risco aceito; allowlist CORS, rate limits, limites de execução/stream, logs redigidos e alertas operacionais; controles não protegem confidencialidade contra chamadas diretas |
| Retry após execução descartada | a mesma chave pode criar nova execução; risco de consulta duplicada aceito para evitar retenção de resultado |
| Cancelamento de chamada em andamento | Dio interrompe a requisição local, mas o portal pode concluir operação já recebida; chamadas canceladas não são repetidas |

## 14. Definition of Done

- Todas as tarefas T1–T10 mergeadas e com push.
- T1, T2, T3 e T7 já estão concluídas em `main`; T4–T6 e T8–T10 estão
  implementadas localmente e aguardam integração.
- Nenhuma rota antiga permanece.
- `dart analyze`, `dart test`, `flutter analyze`, `flutter test` verdes.
- Harness de 12 usuários verde; RSS e duração p50/p95 reportados, sem SLA
  numérico até existir baseline.
- Budget de 500 linhas úteis respeitado em todas as worktrees.
- README, GLOSSARY e ADRs atualizados.
- Nenhum arquivo temporário, identificador real, origem específica, credencial
  ou artefato de build versionado.
