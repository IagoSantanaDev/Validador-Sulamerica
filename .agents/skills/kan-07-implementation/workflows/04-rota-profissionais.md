# WF04: Rota Backend De Profissionais

## Objetivo

Adicionar `POST /api/profissionais` para consultar CFM em lote, sem acoplar a autenticação de sessão do portal SulAmérica nem bloquear as consultas já existentes.

## Propriedade Exclusiva

Pode editar somente:

- `backend/lib/validador_api.dart`
- `backend/test/profissionais_api_test.dart` (novo)

Não edite o cliente CFM, `bin/server.dart`, sessão do portal, testes de outros endpoints, frontend ou documentação.

## Pré-condições E Contrato

- WF03 precisa estar integrado. Importe `ConsultaCfm`, injete a implementação no `ValidadorApi`, e use `ConsultaCfmSoap` como padrão sem quebrar o construtor/call sites existentes.
- Siga `.agents/AGENTS.md`, `debug/KAN-07/PLANO.md` e o estilo shelf-router/Dio já existente.
- Consulte Context7 para APIs Shelf/router, ambiente Dart e qualquer mecanismo de concorrência/cache considerado. Não adicione dependências sem necessidade e consulta Context7.
- Request: `{ "consultas": [{"crm":"...", "uf":"..."}] }`; nunca recebe nome nem token da sessão do portal. Resposta mantém a ordem e retorna dados oficiais ou estado por item.
- Campo ausente/vazio ou UF ausente/inválida não chama CFM. O resultado da UF inválida continua gate aberto no plano: pare para confirmação em vez de inventar estado.

## Execução

1. Estude `_lerJson`, limites de corpo/itens, `_rotasDePortal`, rate limit, `_loteEmAndamento`, logging e testes atuais.
2. Registre rota própria `/api/profissionais`; inclua-a na proteção de rate limit adequada sem depender de token/sessão do portal.
3. Reuse limite de corpo e tamanho máximo de lote existentes; limite/validate itens antes de iniciar chamadas externas. Respostas mantêm posição de cada consulta.
4. Use cache em memória TTL 24 horas apenas para resultados conclusivos, incluindo `naoEncontrado` apenas se a decisão aberta for aprovada. Não cacheie `naoVerificado` nem `falhaConsulta`.
5. Use concorrência pequena e limitada. Não use `_loteEmAndamento`, pois essa rota precisa ser independente de consultas de portal. Isolar falhas por item para que um erro CFM não derrube o lote todo.
6. Não logue nome retornado, chave, CRM completo, payload SOAP ou corpo. Reaproveite `_logger` sem ampliar dados sensíveis.
7. Escreva testes de rota injetando fake CFM: corpo inválido/limites, CRM/UF ausentes, ordem de resposta, falha individual, sem token SulAmérica, cache conclusivo/expiração e não cache de inconclusivo/falha. Evite testes dependentes da rede.

## Aceitação E Limites

- `cd backend; dart test test/profissionais_api_test.dart` (ajuste sintaxe ao shell) e `dart analyze` passam.
- Testes existentes de login/consulta/status continuam passando. Rota não altera comportamento do portal.
- Até 500 linhas alteradas de código de produção, sem contar testes. Se necessário, pare e proponha uma fatia adicional com arquivo de propriedade exclusiva.
- Revise o diff real e audite-o via Context7; cheque staged paths e higiene.

## Encerramento

Após integração do WF03, validação e higiene do worktree, finalize invocando o comando abaixo. Se a rota já estiver correta, não crie commit vazio.

`/simple-commit`
