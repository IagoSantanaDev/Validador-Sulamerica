# WF03: Interface E Documentação Das Regras Locais

## Objetivo

Apresentar os resultados das regras locais 1 e 2 e documentar seus critérios, sem criar consultas ou validações de profissional.

## Propriedade Exclusiva

Pode editar somente:

- `lib/modules/validador_xml/data/models/erro_validacao.dart` (somente se precisar de tipo para os erros das regras 1 e 2)
- `lib/globals/constants/app_strings.dart`
- `lib/modules/validador_xml/presentation/widgets/grade_guias.dart`
- outros widgets de apresentação apenas se forem necessários para esses dois erros e não pertencerem a WF01/WF02
- `README.md`
- testes novos e exclusivos de apresentação em `test/`

Não edite modelos/datasource do solicitante, regras locais, `RegraCodigoBilateral`, controller, serviços, API/backend ou arquivos XML reais.

## Pré-condições E Contratos

- WF02 deve estar integrado. Se os erros das regras 1 e 2 ainda não tiverem contrato estável, pare e relate a dependência; não crie tipos paralelos.
- Siga `.agents/AGENTS.md`, reutilize mensagens, filtros e componentes existentes e mantenha regra de negócio fora dos widgets.
- Consulte Context7 para decisões de Flutter/API de UI; não adicione dependências.
- O CRM aparece como erro local de comprimento literal. A senha VPP tem mensagem própria, distinta de `Senha não informada`, com todos os códigos aplicáveis.

## Execução

1. Inspecione como a grade, os filtros e o resumo exibem `ErroValidacao` atualmente.
2. Ajuste somente o necessário para identificar claramente erros das regras 1 e 2. Preserve as categorias e os fluxos atuais do portal SulAmérica.
3. Atualize `README.md` com os critérios literais do CRM, exceção para valor ausente/vazio, senha obrigatória para códigos VPP e origem/versionamento do conjunto de 2.792 códigos.
4. Não adicione fluxo de consulta remota à validação local.
5. Use testes focados com dados sintéticos e execute `flutter test test/grade_guias_test.dart` e `flutter analyze`.

## Aceitação E Limites

- A grade distingue os erros das regras 1 e 2 sem reclassificá-los como erro de consulta.
- A documentação descreve somente as regras 1 e 2 desta feature e não altera a documentação geral dos endpoints do portal existente.
- Até 500 linhas alteradas de código de produção, sem contar testes e documentação.
- Revise o diff real, audite com Context7, rode as verificações focadas e confirme higiene do staging.

## Encerramento

Após validação e higiene do worktree, finalize invocando o comando abaixo. Se a fatia já estiver satisfeita, não crie commit vazio.

`/simple-commit`
