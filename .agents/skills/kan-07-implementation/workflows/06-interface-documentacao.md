# WF06: Interface, Aceitação E Documentação

## Objetivo

Exibir resultados profissionais/CRM com tipos e contadores corretos, atualizar documentação e executar a verificação de aceitação integrada sem alterar regras de domínio/backend nesta fatia.

## Propriedade Exclusiva

Pode editar somente:

- `lib/modules/validador_xml/data/models/consulta_guia.dart`
- `lib/modules/validador_xml/data/models/erro_validacao.dart` (somente se tipo de erro realmente pertencer a esse modelo)
- `lib/globals/constants/app_strings.dart`
- `lib/modules/validador_xml/presentation/widgets/grade_guias.dart`
- `lib/modules/validador_xml/presentation/widgets/cabecalho_resultado.dart` e outros widgets de apresentação estritamente necessários, após confirmar ownership
- `README.md` e `backend/README.md`
- `test/grade_guias_test.dart` e teste de aceitação sintético novo, exclusivo desta workflow

Não edite parser/modelos do solicitante, regras, service, controller, API backend, adapter CFM ou fixtures XML reais.

## Pré-condições E Contratos

- WF02, WF04 e WF05 devem estar integrados. Se faltar contrato, pare e relate dependência; não crie enum/modelo alternativo na UI.
- Siga padrões visuais já existentes e instruções LEGO em `.agents/AGENTS.md`. Preserve organização, linguagem e componentes usados na grade.
- Consulte Context7 antes de decisão que envolva Flutter, acessibilidade ou API de UI; não adicione dependências.
- As falhas “CRM não verificado” e “Falha na consulta do CRM” são diferentes. “CRM não encontrado”, “UF inválida” e contadores dependem das decisões abertas do plano; confirme que foram aprovadas antes de documentar/contabilizar.
- Nunca inclua no README chave real, nome de paciente/profissional de arquivo real, nem XML do diretório `debug/xml/`.

## Execução

1. Inspecione como `TipoConsultaGuia`, `TipoErroGuia`, mensagens, filtros, diálogo e cabeçalho contam falhas de consulta atualmente.
2. Adicione tipo/filtro `profissional` e tipo de erro `crm` sem quebrar categorias existentes. Substitua ternários incompletos por `switch` exaustivo onde CRM poderia cair em “Carteira”.
3. Apresente mensagens do domínio recebidas do controller sem duplicar regra de classificação em widget. Certifique-se de que não verificado/falha/não encontrado são distinguíveis e de que os contadores incluem a categoria correta conforme contrato aprovado.
4. Atualize README(s) com tabela das regras, endpoint SOAP/operação/códigos confirmados, estados, `CFM_WS_CHAVE` runtime-only, fonte da lista VPP e limites/validação pendente. Não afirme contrato ainda não validado nem consulta real concluída.
5. Use uma fixture XML pequena, sintética e sem identificadores reais para teste integrado. Não copie nem versiona os anexos de `debug/xml/`.
6. Rode testes focados de grade/aceitação e os comandos finais: `flutter analyze`, `flutter test`, `cd backend; dart analyze`, `dart test`. Se o ambiente não tiver dependências, registre exatamente o bloqueio.
7. Verifique higiene do repositório: artefatos temporários, XML reais, segredos, build/cache e staged files. Não remova arquivos preexistentes do usuário.

## Aceitação E Limites

- A grade mostra a categoria CRM correta; nenhum estado é confundido com “Carteira” ou “Senha não informada”.
- Documentação cita apenas comportamentos/contratos confirmados e chama pendências pelo nome.
- Até 500 linhas alteradas de código de produção, sem contar testes e documentação. Se exceder, pare e proponha outra fatia sem apropriar arquivos de workflows anteriores.
- Revise o diff final integrado e faça auditoria Context7 dos arquivos efetivamente alterados.

## Encerramento

Após todos os checks aplicáveis e higiene do worktree, finalize invocando o comando abaixo. Se nenhum arquivo precisar mudar, informe que a fatia já está satisfeita sem commit vazio.

`/simple-commit`
