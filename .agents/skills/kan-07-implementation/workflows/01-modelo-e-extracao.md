# WF01: Extração Literal Do CRM

## Objetivo

Disponibilizar para a Regra 1 o número do conselho extraído exclusivamente de `dadosSolicitante/profissionalSolicitante`, preservando cada caractere para a contagem literal do CRM.

## Propriedade Exclusiva

Pode editar somente:

- `lib/modules/validador_xml/data/models/profissional_solicitante.dart` (novo, contendo somente `numeroConselho`)
- `lib/modules/validador_xml/data/models/guia_tiss.dart`
- `lib/modules/validador_xml/data/datasources/xml_lote_guias_datasource.dart`
- testes novos e exclusivos para o modelo/datasource em `test/`

Não altere regras, controller, service, UI, README, backend ou arquivos XML do diretório `debug/xml/`.

## Pré-condições E Contrato

- Siga `.agents/AGENTS.md` e as regras/decisões fechadas em `debug/KAN-07/PLANO.md`.
- Confira `pubspec.yaml`: use o pacote `xml` já existente e os helpers de caminho aninhado no datasource. Não adicione dependência.
- O modelo `ProfissionalSolicitante` expõe somente `numeroConselho`, preservado sem `trim`, remoção de zeros ou qualquer normalização. `GuiaTiss.solicitante` é opcional e não quebra construtores existentes.
- O modelo contém somente o valor necessário à contagem literal do CRM.
- Use fixture TISS sintética e pequena com namespace e valores fictícios em `profissionalSolicitante` e `equipeSadt`, provando que a origem é a correta.

## Execução

1. Inspecione os modelos/datasource vizinhos, testes existentes e versão `xml` instalada; consulte Context7 antes de decidir sobre APIs ou dependências.
2. Implemente o modelo imutável mínimo e estenda `GuiaTiss` com `solicitante` opcional.
3. Extraia somente `numeroConselhoProfissional` pelo caminho direto `dadosSolicitante/profissionalSolicitante`; preserve literalmente o texto e não use busca descendente que possa capturar `equipeSadt`.
4. Trate campo ausente/vazio conforme o padrão de nulabilidade existente, sem criar valores artificiais.
5. Teste campo presente/ausente, espaços preservados, namespace TISS e garantia de que um número em `equipeSadt` não seja usado.

## Aceitação E Limites

- Os testes do datasource/modelo passam e a análise Flutter não introduz erros.
- Construtores existentes de `GuiaTiss` continuam válidos sem `solicitante`.
- A Regra 1 recebe o valor literal do nó correto. Nenhum XML real ou dado pessoal é adicionado ao Git.
- Até 500 linhas alteradas de código de produção, sem contar testes. Se estourar, pare e proponha uma nova fatia; não reduza cobertura.
- Revise o diff, audite-o com Context7, rode as verificações focadas e confirme que apenas os arquivos próprios estão staged.

## Encerramento

Após validação e higiene do worktree, finalize invocando o comando abaixo. Se a fatia já estiver completa, apenas reporte que está satisfeita; não crie commit vazio.

`/simple-commit`
