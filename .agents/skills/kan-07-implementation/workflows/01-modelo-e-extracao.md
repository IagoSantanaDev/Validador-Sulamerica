# WF01: Modelo Do Solicitante E Extração XML

## Objetivo

Adicionar ao modelo de guia os dados do profissional solicitante e extrair esses campos exclusivamente de `dadosSolicitante/profissionalSolicitante`. Implementar o mapa IBGE de UF necessário à consulta CFM, sem ler `equipeSadt`.

## Propriedade Exclusiva

Pode editar somente:

- `lib/modules/validador_xml/data/models/profissional_solicitante.dart` (novo)
- `lib/modules/validador_xml/data/models/guia_tiss.dart`
- `lib/modules/validador_xml/data/models/uf_ibge.dart` (novo)
- `lib/modules/validador_xml/data/datasources/xml_lote_guias_datasource.dart`
- testes novos e exclusivos para o modelo/mapa/datasource em `test/`

Não altere regras, controller, service, UI, README, backend ou arquivos XML do diretório `debug/xml/`.

## Pré-condições E Contrato

- Siga `.agents/AGENTS.md` e as regras/decisões fechadas em `debug/KAN-07/PLANO.md`.
- Confira `pubspec.yaml`: use o pacote `xml` já existente e os helpers de caminho aninhado no datasource. Não adicione dependência.
- O modelo `ProfissionalSolicitante` expõe `nome`, `numeroConselho` e `uf`, preservando exatamente o conteúdo XML relevante; CRM literal não pode receber `trim` (D6). `GuiaTiss.solicitante` é opcional e não quebra construtores/call sites existentes.
- UF aceita sigla e códigos IBGE string, com conversão explícita para sigla quando válido. Não invente resultado de validação para UF inválida; esse resultado está aberto no plano.
- Confirme o formato/schema nos exemplos fornecidos sem copiar dados pessoais. Faça fixtures sintéticas pequenas com namespace TISS e dois caminhos concorrentes (`profissionalSolicitante` e `equipeSadt`) para provar a origem correta.

## Execução

1. Inspecione os modelos e datasource vizinhos, testes existentes e versão `xml` instalada.
2. Antes de editar, consulte Context7 para APIs do pacote XML e Dart usadas nesta extração; não expanda escopo nem introduza pacote.
3. Implemente o modelo imutável seguindo o estilo local e estenda `GuiaTiss` com parâmetro opcional.
4. Extraia nome, número de conselho e UF somente pelo caminho aninhado do solicitante. Não use busca descendente genérica que possa selecionar `equipeSadt`. Preserve o CRM sem trim e trate elemento ausente/vazio sem criar dados artificiais.
5. Adicione mapa IBGE→sigla com os 27 códigos, aceitando sigla já normalizada conforme o contrato local.
6. Escreva testes sintéticos para campos presentes/ausentes, CRM com espaços preservados, namespace, UF (incluindo `29`→`BA`) e garantia de não ler dados de `equipeSadt`.

## Aceitação E Limites

- Os testes do datasource e modelos passam e a análise Flutter não introduz erros.
- Construtores existentes de `GuiaTiss` continuam válidos sem `solicitante`.
- Nenhum XML real, nome ou dado de beneficiário é adicionado ao Git.
- Até 500 linhas alteradas de código de produção, sem contar testes. Se estourar, pare e proponha uma nova fatia; não reduza cobertura.
- Revise o diff, audite-o com Context7, rode as verificações focadas e confirme que apenas os arquivos próprios estão staged.

## Encerramento

Após validação e higiene do worktree, finalize invocando o comando abaixo. Se a fatia já estiver completa, apenas reporte que está satisfeita; não crie commit vazio.

`/simple-commit`
