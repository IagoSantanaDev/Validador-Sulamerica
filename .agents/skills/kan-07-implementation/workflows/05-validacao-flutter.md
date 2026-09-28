# WF05: Consulta E Regra CFM No Flutter

## Objetivo

Conectar o serviço Flutter ao endpoint de profissionais, implementar classificação pura dos resultados CFM e acoplar essa validação ao controller como etapa separada da consulta de guias.

## Propriedade Exclusiva

Pode editar somente:

- novos modelos Flutter de request/resultado CFM em `lib/modules/validador_xml/data/models/`
- `lib/modules/validador_xml/data/services/sul_america_backend_service.dart`
- novo arquivo de regra pura `lib/modules/validador_xml/data/repositories/regras/regra_crm_cfm.dart`
- `lib/modules/validador_xml/presentation/controllers/validador_controller.dart`
- testes novos e exclusivos desses arquivos em `test/`

Não edite `GuiaTiss`, datasource, regra local de tamanho/VPP, `validador_api.dart`, tipos de UI (`TipoErroGuia`, `TipoConsultaGuia`), widgets ou README.

## Pré-condições E Contratos

- WF01 deve estar integrado para `GuiaTiss.solicitante`; WF04 deve estar integrado para endpoint, estados e JSON. Se não estiverem, implemente apenas os próprios modelos/service/regra contra o contrato do plano e mantenha controller isolado até as dependências estarem disponíveis; não crie stubs de produção duplicados.
- Reuse o padrão de `consultarLote`, `Result`, GetIt e `GuiaValidada`. Inspecione call sites e fakes.
- Siga decisões D1-D7 e P1-P7. A consulta é deduplicada por `(CRM numérico, UF)`; 014481 pode falhar tamanho literal sem impedir consulta CFM. Sem nome/CRM no body da rota.
- Consulte Context7 para Dio/Flutter/Dart nas APIs efetivamente usadas. Não adicione dependências.

## Execução

1. Adicione DTO imutável do resultado (estado, CRM, UF, nome, situação, tipo de inscrição, data de atualização e especialidade) e método de serviço `consultarProfissionais`, no padrão local.
2. Implemente regra pura para resultados: CRM ausente local; falha de consulta; não encontrado (só se decisão aberta aprovada); não verificado para dados insuficientes; não confere; CRM inativo; conforme.
3. Nome compatível: comparar sem acento/caixa/pontuação, primeiro e último tokens iguais, demais tokens do nome menor aparecem em ordem no maior, inteiros ou como inicial. Não remova prefixo `EQ ...`; compare como veio. CRM/UF retornados devem corresponder à consulta.
4. Situação não interpretável ou nome/dados essenciais vazios => não verificado. Situação inativa só vira erro próprio depois de correspondência de CRM+UF e nome.
5. No controller, rode etapa de profissional separada e posterior a `_consultarGuias`; falha não apaga resultados existentes nem impede regras locais. Não condicione a consulta CFM à credencial de portal SulAmérica. Preserve o processamento do lote quando a chamada CFM falhar.
6. Cubra testes da regra para conforme, incompatível, inativo, não encontrado, ausente, falha, inconclusivo, zero à esquerda, outra UF, iniciais, acentos, pontuação e prefixo EQ. Teste controller para deduplicação, regra rodando sem credencial, independência das falhas e lote preservado.

## Aceitação E Limites

- Unit tests novos e testes focados de service/controller passam; `flutter analyze` não introduz erro.
- Contrato de estados e JSON permanece compatível com WF04; não altere UI nesta etapa.
- Até 500 linhas alteradas de código de produção, sem contar testes. Se ultrapassar, pare e proponha uma fatia de controller separada, sem quebrar ownership.
- Faça auditoria Context7 do diff real e confirme higiene/staging.

## Encerramento

Após validação e higiene do worktree, finalize invocando o comando abaixo. Marque a consulta real CFM como pendente quando não houver chave; nunca use credenciais em teste versionado. Se já satisfeito, não crie commit vazio.

`/simple-commit`
