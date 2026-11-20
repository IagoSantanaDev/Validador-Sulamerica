# Contexto: estabilização do portal SulAmérica

Atualizado em 2026-11-20; T6/T7 implementados, reteste de carga pendente.
Documento para retomar o trabalho sem depender do histórico do chat.

## Objetivo e critérios

Investigar falhas do portal SulAmérica sob carga e mitigá-las sem afirmar causa
raiz sem evidência. O critério de aceite prioritário continua sendo 6 sessões ×
200 itens com 100% de respostas válidas, zero falhas ao criar sessão e lote em
até 10 minutos (meta de 5 minutos). O cenário 12 × 200 é aspiracional.

O plano de referência é `C:\Users\Administrator\Downloads\plano-estabilizacao-portal.md`.
As decisões relevantes incluem: existem duas credenciais de portal, uma por
CNPJ; backoff e limites devem ser configuráveis por ambiente; F5 é hipótese,
nunca causa presumida; Support IDs ficam temporariamente disponíveis em
`/api/status` atrás de flag e serão removidos no fechamento.

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
- Métricas agregadas e Support IDs opcionais em `/api/status`.
- Header para distinguir 502 da API de 502 de proxy.
- Harness `backend/tool/matriz_carga.dart` com E1/E2/E3, modo lote/item e CSV.
- CSV da matriz agora preserva mensagens de erro sanitizadas por item.
- Retries de consulta configuráveis por `PORTAL_RETRY_MAX_TENTATIVAS` (default
  3), `PORTAL_RETRY_BACKOFF_BASE_MS` (1000),
  `PORTAL_RETRY_BACKOFF_MAX_MS` (20000) e `PORTAL_RETRY_JITTER_PERCENT` (30).
- `/api/status` informa configuração efetiva e contadores de retries iniciados,
  resolvidos e esgotados em `resilienciaPortal`.
- T5: limite global de 2 logins simultâneos por padrão, configurável por
  `PORTAL_LOGIN_MAX_CONCORRENCIA` (faixa 1–16); métricas de ativos, pico e fila
  em `concorrenciaPortal.logins`. Limite de 4 sessões por CNPJ permanece igual.
- Validação desta retomada: `dart analyze` e `flutter analyze` sem achados;
  suítes completas com 166 testes backend e 164 Flutter passando. Testes usam
  adapters falsos; carga local integrada ainda pendente.
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

## Fase 2: o que falta

T6/T7 e a atualização inicial do contrato/documentação estão implementados.
Ainda faltam:

1. Validar T5 em execução local com `/api/status` e carga curta. O teto por CNPJ
   continua em 4; E2 sequencial não justifica alterá-lo.
2. T9: retestar 6 × 200 e 12 × 200 em local e Render após as mitigações; o
   aceite de 100% ainda não foi atingido.
3. T10/T11: remover Support IDs de `/api/status`, mantendo contadores agregados,
   e registrar conclusão/higiene do repositório.

O resultado E2 não sustenta a escolha do ramo de sessão única por conta. É
razoável prosseguir com limite de múltiplas sessões, mas ainda como mitigação
controlada: usar defaults configuráveis, expor picos/esperas, fazer teste
focalizado antes de nova E1 completa e não atribuir causa raiz sem sinais
convergentes.

## Próximos passos recomendados

1. Validar breaker e contrato parcial com adapters falsos, depois reiniciar o
   backend e confirmar o teto e as métricas em
   `/api/status.concorrenciaPortal.logins`; teste com adapters falsos já cobre o
   limite e a fila.
2. Fazer uma carga local curta; se estável, rodar E1 6 × 200 completa local.
   Comparar com a linha de base, sem repetir a carga Render já registrada até
   definir a etapa de reteste.

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
