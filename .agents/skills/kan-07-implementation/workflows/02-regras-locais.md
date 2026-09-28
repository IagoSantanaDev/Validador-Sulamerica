# WF02: Regras Locais De CRM E Senha VPP

## Objetivo

Implementar a regra literal de tamanho do CRM e substituir a lista reduzida de autorização por senha pelo conjunto VPP completo de 2.792 códigos de `debug/KAN-07/procedimentos_vpp_sim.json`.

## Propriedade Exclusiva

Pode editar somente:

- `lib/modules/validador_xml/data/repositories/regras/regra_crm_tamanho.dart` (novo)
- `lib/modules/validador_xml/data/repositories/regras/regra_senha_procedimento.dart` (novo)
- arquivo de dados Dart dedicado e compactado do conjunto VPP, se necessário
- `lib/modules/validador_xml/data/repositories/regras/regra_senha_prefixo.dart`
- `lib/modules/validador_xml/data/repositories/validador_guias_repository_impl.dart`
- testes novos/exclusivos em `test/` para estas regras e para o guard de consistência VPP

Não edite modelo/datasource, `RegraCodigoBilateral`, controller, UI, README ou backend.

## Pré-condições E Contrato

- Siga `.agents/AGENTS.md` e `debug/KAN-07/PLANO.md`. WF01 precisa estar integrado: use `GuiaTiss.solicitante.numeroConselho` para a regra de CRM.
- Leia os padrões `RegraValidacao`, `ErroValidacao` e registro no repository antes de decidir a assinatura.
- Consulte Context7 para decisões de linguagem/pacote usadas; não adicione dependência. A lista é dado de domínio, não deve ser lida em runtime.
- Regra CRM conta exatamente o valor extraído; não faz `trim`, remove zero ou normaliza dígitos. Valor ausente/vazio não dispara erro. Comprimento maior que 5 gera campo `crm` e mensagem conforme o plano.
- Regra VPP gera no máximo um erro por guia sem senha, contendo todos os códigos aplicáveis. A mensagem não contém a substring `senha não informada`. Uma guia sem código VPP não é afetada.
- `RegraSenhaPrefixo` não gera o erro duplicado de senha obrigatória quando a regra VPP se aplica. Não compartilhe a lista com `RegraCodigoBilateral`.

## Execução

1. Verifique a pré-condição WF01 e descubra como o projeto representa senha ausente e código de procedimento.
2. Leia `procedimentos_vpp_sim.json` com parser JSON no teste/geração, compare a contagem informada (2.792), unicidade e conteúdo. Não copie o JSON inteiro como fixture e não o abra para despejar dados no log.
3. Consulte Context7 antes de definir codificação/representação do conjunto. Gere estrutura Dart imutável, lookup O(1), sem leitura de arquivo no runtime e sem dependência nova. Mantenha o payload de dados compacto; o limite de 500 linhas aplica-se a código de produção, não a testes.
4. Implemente e registre as regras seguindo o repository atual. Mantenha `RegraCodigoBilateral` inalterada.
5. Ajuste `RegraSenhaPrefixo` apenas para eliminar duplicação quando VPP exigir senha.
6. Cubra CRM com 4/5/6 dígitos, `014481`, ausente, vazio e espaços sem trim. Cubra códigos VPP no início/meio/fim do conjunto, senha ausente/presente, múltiplos alvos num único erro, sem alvo e não duplicação.
7. Adicione guard automático que compare o conjunto em código com a fonte JSON e falhe quando houver divergência ou contagem diferente, sem atualizar silenciosamente a fonte.

## Aceitação E Limites

- `flutter test` dos testes novos e vizinhos passa; regra bilateral permanece inalterada.
- Conjunto de runtime contém exatamente 2.792 códigos únicos e nenhum arquivo é lido em runtime.
- Até 500 linhas alteradas de código de produção, sem contar testes. Se exceder, pare e decomponha o payload/implementação sem violar a forma imutável e O(1).
- Faça diff real, auditoria Context7, validação focada e higiene de staging.

## Encerramento

Após validação e higiene do worktree, finalize invocando o comando abaixo. Se a fatia já estiver completa, reporte-a sem criar commit vazio.

`/simple-commit`
