# Contexto: estabilização do portal SulAmérica

Atualizado após T10/T11; T6/T7 implementados, T9 executado localmente e no
Render; 6 × 200 teve 100% de `sucesso` no harness, 12 × 200 foi parcial.

## Objetivo e critérios

Investigar falhas do portal SulAmérica sob carga e mitigá-las sem afirmar causa
raiz sem evidência. O critério de aceite prioritário continua sendo 6 sessões ×
200 itens com 100% de respostas válidas, zero falhas ao criar sessão e lote em
até 10 minutos (meta de 5 minutos). O cenário 12 × 200 é aspiracional.

O plano de referência é `C:\Users\Administrator\Downloads\plano-estabilizacao-portal.md`.
As decisões relevantes incluem: existem duas credenciais de portal, uma por
CNPJ; backoff e limites devem ser configuráveis por ambiente; F5 é hipótese,
nunca causa presumida; `/api/status` expõe somente métricas agregadas e não
retém nem publica Support IDs individuais.

## Estado confirmado dos experimentos

- E1 Render: 1.199/1.200 respostas válidas; uma falha residual sem categoria
  detalhada no resultado original; zero 429/502.
- E1 local antes de retries: 1.198/1.200; duas falhas de elegibilidade sem
  diagnóstico por item; duração 159,6 s.
- E1 local com retries de falhas transitórias: 1.199/1.200; uma falha; zero
  429/502; duração 171,7 s.
- A única consulta residual dessa E1 foi repetida individualmente e passou.
  Isso sugere transitoriedade, mas não identifica o status ou a causa original.
- E2 direto, executado em 2026-11-20 contra o portal: 6/6 logins em instâncias
  independentes passaram; sondas da primeira sessão antes/depois de 2 e 4
  logins adicionais passaram (4/4 HTTP 200); nenhum 401/403 observado. Duração
  total 11,66 s; latência das sondas p50 625 ms. CSV local:
  `%TEMP%\matriz-carga-2026-11-20T13-43-58.298433Z.csv`.

O E2 reduz o suporte à hipótese H1 (um novo login sempre invalida a sessão
anterior) para esta sequência, credencial e massa de teste. Não a elimina em
geral: os logins foram sequenciais, não simultâneos, e cada braço fez uma
consulta de elegibilidade à mesma sessão original. Também não há evidência que
confirme H2 (bloqueio por IP) ou H3 (rajada de logins). Não repetir o E2 sem
decidir qual variável adicional se quer testar.

## Código já implementado

- Assinaturas de respostas inesperadas do portal sem armazenar/logar o body.
- Métricas agregadas em `/api/status`, sem publicar ou reter Support IDs
  individuais.
- Header para distinguir 502 da API de 502 de proxy.
- Harness `backend/tool/matriz_carga.dart` com E1/E2/E3, modo lote/item e CSV.
- CSV da matriz agora preserva mensagens de erro sanitizadas por item.
- Retries de consulta configuráveis por `PORTAL_RETRY_MAX_TENTATIVAS` (default
  3), `PORTAL_RETRY_BACKOFF_BASE_MS` (1000),
  `PORTAL_RETRY_BACKOFF_MAX_MS` (20000) e `PORTAL_RETRY_JITTER_PERCENT` (30).
- `/api/status` informa configuração efetiva e contadores de retries iniciados,
  resolvidos e esgotados em `resilienciaPortal`.
- `resilienciaPortal.retriesAgendador` conta separadamente os retries do
  agendador: `iniciados` após o backoff e a permissão do disjuntor,
  `resolvidos` quando uma tentativa posterior tem sucesso e `esgotados` quando
  a última tentativa permitida termina ainda retryable. Cancelamentos durante
  o backoff não contam como iniciados; uma cadeia encerrada por erro não
  retryable não conta como esgotada.
- T10/T11 concluídos: removidos da API, da flag de configuração e dos buffers
  de sessão os valores individuais de Support ID; permanece somente o contador
  agregado `assinaturaF5MarkerSupportId`.
- T5: limite global de 2 logins simultâneos por padrão, configurável por
  `PORTAL_LOGIN_MAX_CONCORRENCIA` (faixa 1–16); métricas de ativos, pico e fila
  em `concorrenciaPortal.logins`. Limite de 4 sessões por CNPJ permanece igual.
- Validação desta retomada: `dart analyze` e `flutter analyze` sem achados;
  suítes completas com 166 testes backend e 164 Flutter passando. Testes
  automatizados usam adapters falsos; os retestes integrados estão registrados
  abaixo.
- Respostas de transporte com status 408/500/502/503/504 podem ser repetidas,
  assim como transporte sem resposta. HTTP 429 não é repetido. Qualquer
  resposta assinada como F5 não é repetida, inclusive quando vem anexada a um
  `DioException` cujo tipo é transporte. O login aplica a mesma distinção.
- E2 agora instancia `SessaoPortal` diretamente, fora do pool da API, e permite
  desativar somente a renovação automática de sessão nas sondas; retries de
  transporte continuam habilitados. Requer as variáveis locais
  `PORTAL_PRESTADOR_ID_<CNPJ>_{CODE,USER,SENHA}`.
- T6 implementado: disjuntor global em memória abre após 5 falhas elegíveis em
  60 s; cooldown de 60 s, sonda HTTP half-open, 503/Retry-After nas rotas de
  sessão e lote, com replay idempotente preservado. `/api/status` expõe
  `disjuntorPortal`.
- T7 implementado: até quatro tentativas totais por item no agendador; retries
  aguardam o disjuntor, lote para de iniciar itens aos 5 minutos e finaliza
  depois das chamadas já em andamento. SSE declara `status: parcial` e lista
  `pendentes` com motivo; frontend aplica resultados e oferece retry manual.
  `/api/status.lotes.parciais` conta as finalizações parciais.
- Cliente: 503 é tipado, reaproveita política de 429 (uma repetição para sessão,
  até três para lote com chave idempotente), respeitando `Retry-After` até 60 s.
- Reteste T9 em 2026-11-20, usando o XML local com 107 consultas distintas
  (72 carteirinhas e 35 senhas), repetidas em ciclo para completar cada lote:
  - Carga curta local, 6 × 10: 60/60 com `sucesso: true` em 17,3 s; zero
    falhas.
  - Local, 6 × 200: 1.200/1.200 com `sucesso: true` em 157,2 s; seis lotes
    concluídos, nenhum parcial.
  - Render, 6 × 200: 1.200/1.200 com `sucesso: true` em 193,6 s; seis lotes
    concluídos, nenhum parcial. Pelo indicador do harness, o critério
    prioritário de 100% em até 10 min (meta 5 min) passou nos dois ambientes.
  - Local, 12 × 200: 2.215 com `sucesso: true`, 2 falhas e 183 itens sem
    resultado (2.217 resultados recebidos), em 316,7 s; 1 lote concluído e 11
    parciais.
  - Render, 12 × 200: 1.804 com `sucesso: true`, 2 falhas e 594 itens sem
    resultado (1.806 resultados recebidos), em 304,2 s; 12 lotes parciais. O
    cenário aspiracional não atingiu 100%; o limite de despacho de cinco
    minutos foi alcançado. As duas falhas reportadas em cada ambiente vieram
    como falha de consulta no resultado SSE HTTP 202, sem causa específica no
    harness.
- Limitação do indicador de sucesso: o harness confere `sucesso`, mas não
  valida os campos de domínio opcionais `elegivel` e `statusSenha`; esses campos
  podem ser nulos e não são preservados no CSV. Assim, 100% acima significa
  100% de respostas marcadas `sucesso: true`, não uma verificação independente
  de todos os valores de domínio.
- T5 observado em `/api/status`: limite 2 e pico de 2 logins ativos no backend
  local e no Render; pico de espera por login zero. Após as cargas, ambos os
  serviços responderam 200, com disjuntor fechado e sem lotes ativos/em fila.
  Não houve HTTP 429/502 nos quatro retestes. O `/api/status` local terminou
  com 8 falhas upstream 503 agregadas; no Render, zero.
- Reteste adicional em 2026-11-20, a pedido, com o arquivo desidentificado
  `521358.xml` (107 consultas únicas extraídas; 72 de elegibilidade e 35 de
  senha), repetidas em ciclo para formar os lotes:
  - Render, 6 × 200: 1.199 sucessos, 1 falha e nenhum item sem resultado;
    duração 209,9 s.
  - Render, 12 × 200: 1.778 sucessos, 2 falhas e 620 itens sem resultado;
    duração 304,3 s; os 12 lotes ficaram parciais.
  - Local, 6 × 200: 1.200/1.200 sucessos, sem falhas ou itens sem resultado;
    duração 161,0 s.
  - Local, 12 × 200: 2.311 sucessos, 4 falhas e 85 itens sem resultado;
    duração 302,0 s; 1 lote concluído e 11 parciais.
  - As falhas recebidas foram reportadas pelo harness como “Falha na consulta
    ao portal SulAmerica”, sem status HTTP associado; a causa permanece
    indeterminada. Nenhum cenário registrou HTTP 429 ou 502.
  - Após os testes, `/api/status` respondeu `ok` em ambos os ambientes, sem
    lotes ativos ou em fila e com o disjuntor fechado. O local reportou 9
    retries do agendador iniciados e resolvidos, nenhum esgotado, e zero
    falhas upstream 502 e 9 falhas upstream 503; Render reportou os três
    contadores de retry e as falhas upstream 502/503 em zero.
- Naquelas execuções 12 × 200, `resilienciaPortal.retriesTransitorios*`
  permaneceu zero. Como o backend desativa o retry interno da `SessaoPortal` e
  delega as tentativas ao agendador, esses valores históricos não mediam a
  camada do agendador. Ela agora possui os contadores independentes
  `resilienciaPortal.retriesAgendador`.

## Estado da estabilização

T6/T7, instrumentação dos retries do agendador e T10/T11 estão implementados.
Os testes confirmam a contagem de retries resolvidos/esgotados, a ausência de
valores individuais e a preservação da métrica agregada. O cenário aspiracional
12 × 200 permanece parcial conforme os resultados acima.

O resultado E2 não sustenta a escolha do ramo de sessão única por conta. É
razoável prosseguir com limite de múltiplas sessões como mitigação controlada:
usar defaults configuráveis, expor picos/esperas e não atribuir causa raiz sem
sinais convergentes.

## Próximo passo recomendado

Considerar novo teste 12 × 200 somente após decidir se a meta aspiracional
continua sujeita ao limite de cinco minutos ou se o perfil de capacidade deve
mudar. O critério prioritário 6 × 200 passou localmente e no Render.

## Comandos úteis

E2 direto, com credenciais já configuradas apenas no ambiente local:

```powershell
Set-Location backend
dart run tool/matriz_carga.dart --xml "C:\Users\Administrator\Downloads\521358.xml" --cenario e2
```

Validação backend:

```powershell
Set-Location backend
dart analyze
dart test
```

Não adicionar CSVs, XMLs de teste, credenciais, tokens ou bodies de portal ao
Git. O CSV E2 acima permanece somente no diretório temporário local.

## Git nesta retomada

- Branch: `main`; commits de implementação, harness, testes, higiene e lint
  foram enviados: `8a442c3`, `3ab3463`, `647921c`, `08486e5` e `e172770`.
- Este documento acompanha a atualização de comportamento e validação.
- O documento `.agents/memoria.md` está coberto por `.gitignore` (`.agents/*`);
  seus aprendizados são locais e não serão enviados com commits normais.
- Nenhum CSV, XML, `.env`, credencial ou body do portal foi incluído nos commits.
