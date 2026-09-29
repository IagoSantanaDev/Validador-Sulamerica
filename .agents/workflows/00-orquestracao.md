# Orquestracao de correcoes KAN-08

## Objetivo

Executar os tres workflows independentes desta pasta em subagents paralelos, cada um em worktree exclusiva, com alteracoes idempotentes e limitadas a 500 linhas de codigo de producao por workflow. Ao final, os commits de cada workflow devem ser integrados, em serie, na branch principal `KAN-08`.

Estes arquivos sao especificacoes Markdown para o agente coordenador. O VS Code nao descobre automaticamente arquivos arbitrarios em `.agents/workflows` como comandos slash. O coordenador deve abrir e fornecer o conteudo de cada arquivo ao subagent designado. Nao anuncie que cada arquivo e um comando nativo do VS Code.

## Autoridade e precondicoes

1. Leia e siga `.agents/AGENTS.md` integralmente. Requisitos explicitos do usuario prevalecem.
2. A branch alvo e `KAN-08`. Confirme o nome exato antes de qualquer operacao Git.
3. Inspecione `git status --short --branch`, diff staged/unstaged, arquivos untracked, branch atual e `git worktree list`.
4. Nao use, limpe, mova ou inclua alteracoes preexistentes do usuario. Se `KAN-08` ou a worktree de origem estiver suja, pare e reporte; nao use stash, reset, checkout ou clean para contornar.
5. Confirme que o repo e remoto permitem push. Nao force push, nao altere protecoes e nao publique secrets.
6. Antes de qualquer decisao tecnica ou edicao, consulte Context7 com a stack/versao/configuracao real. Se Context7 nao estiver disponivel, pare antes de editar codigo e reporte o bloqueio; nao simule a consulta.

## Contratos compartilhados

- Login recebe somente `{identificadorPrestador: <identificador normalizado>}`. O backend resolve `code`, `user` e `senha` a partir de secrets/configuracao do servidor. A resposta de sucesso preserva `{token, autenticada: true}`.
- O frontend nao contem credenciais `PORTAL_*` no codigo, build args, `--dart-define`, logs ou artefatos publicados. Reutilize no ambiente do backend os nomes de secrets existentes somente se a configuracao de deploy e o codigo confirmarem que isso e seguro.
- O lote continua usando `POST /api/consultas` e os itens `{tipo, chave}`. O servidor mantem limite de 300 itens e 1 MB; o cliente deve particionar lotes maiores e recompor resultados pela chave composta `tipo|chave` sem perder duplicatas/ordem das guias.
- Nunca aceitar certificado apenas por hostname ou retornar `true` sem validar uma cadeia confiavel, CA dedicada ou pinning justificado e testavel. Documente rotacao/renovacao e comportamento em falha.
- O estado de sessao continua sendo local ao processo do backend, salvo se uma mudanca arquitetural for explicitamente aprovada. Nao habilite replicas como solucao incidental.

## Worktrees e paralelismo

Crie uma worktree Git independente por workflow, todas originadas do mesmo commit base atualizado de `KAN-08`. Use nomes estaveis de branch, por exemplo `kan-08/wf-api-seguranca`, `kan-08/wf-frontend-resiliencia` e `kan-08/wf-docs-residuos`; coloque as worktrees fora da pasta do repositorio. Se branch/worktree de uma execucao anterior existir, inspecione-a e reutilize-a somente se pertencer ao mesmo workflow e estiver limpa. Nunca sobrescreva ou apague worktree desconhecida.

Dispare em paralelo:

- `01-api-sessao-seguranca.md`
- `02-frontend-validacao-resiliente.md`
- `03-documentacao-e-residuos.md`

Cada subagent pode editar somente os arquivos de sua propriedade indicados no respectivo workflow. O conteudo deste arquivo congela o contrato entre as frentes. Se uma implementacao exigir mudar o contrato, pare e coordene uma revisao antes de editar; nao permita que dois agentes alterem a mesma interface em paralelo.

## Idempotencia e limite de escopo

Cada subagent compara o estado atual com o resultado esperado antes de editar. Se todos os criterios de sua frente ja forem verdadeiros, nao cria diff e reporta `ja satisfeito`. Nao reintroduza codigo, testes, rotas ou credenciais removidos.

Conte LOC de producao como linhas adicionadas mais linhas removidas no diff, excluindo testes e documentacao. Se a execucao exceder 500 LOC de producao, nao continue ampliando-a: reduza o escopo mantendo o estado coerente ou pare e proponha uma etapa posterior. Nao crie uma implementacao parcial insegura para caber no limite.

## Validacao dos subagents

Cada subagent deve:

1. Adicionar/ajustar testes que demonstrem o comportamento e o rerun seguro.
2. Executar os checks nativos da sua frente indicados no arquivo correspondente.
3. Inspecionar diff e referencias, verificar que so alterou arquivos autorizados e contar LOC.
4. Verificar ausencia de secrets em arquivos, logs, respostas e artefatos web quando aplicavel.
5. Informar commit SHA, branch remota, arquivos, LOC de producao, comandos e resultados, riscos restantes e se a frente ja estava satisfeita.

Falha de teste, analyzer, conflito de contrato, duvida sobre secret/TLS, excesso de LOC ou arquivo fora da propriedade bloqueia commit e merge. Nao silencie falhas.

## Commit e merge obrigatorios

A frente nao esta concluida ate seu commit ser integrado em `KAN-08`.

1. Em cada worktree limpa, apos validacao, invoque `/simple-commit`. A skill analisa as mudancas, cria commits pequenos por intencao, usa Conventional Commits em pt-BR, sem scope, e faz push imediatamente depois de cada commit. Nunca inclua secrets, builds, caches ou arquivos de outra frente. Se nao houver diff porque o workflow ja esta satisfeito, a skill nao deve criar commit vazio.
2. O subagent entrega SHA e branch remota ao coordenador. Ele nao altera `KAN-08` enquanto os demais subagents ainda trabalham.
3. Depois que todas as frentes terminarem, o coordenador adquire exclusividade sobre a integracao. Atualiza `KAN-08` sem descartar mudancas e integra uma branch por vez, em serie, usando merge normal (sem force push/rebase destrutivo). Antes de cada merge, verifica se os commits ja estao contidos em `KAN-08`; se sim, trata o rerun como no-op. Para uma frente sem diff nem commit novo, nao crie merge vazio: confirme se o estado ja existe em `KAN-08` e registre a frente como no-op.
4. Se houver conflito, protecao de branch, push rejeitado ou falta de permissao, pare. Nao resolva conflitos de ownership presumindo intencao e nao contorne protecoes. Reporte o estado local/remoto para recuperacao explicita.
5. Rode a validacao da frente apos cada merge e a suite completa apos a ultima integracao. Envie a branch `KAN-08` ao remoto somente apos validar o resultado integrado. Se o push da branch principal falhar, reporte que o merge local existe mas nao esta publicado.
6. Confirme `git status --short --branch`, SHAs integrados, pushes e worktrees restantes. Remova somente worktrees que o coordenador criou, que estejam limpas e cuja branch ja esteja integrada; nao apague branches remotas.

O coordenador nao deve commitar mudancas preexistentes da worktree principal. A skill `/simple-commit` aplica-se aos commits de cada frente; o merge na branch principal e uma etapa separada de integracao.

## Validacao final

- Flutter: `flutter analyze` e `flutter test` na raiz.
- Backend: `dart analyze` e `dart test` em `backend/`.
- Quando viavel: build web Flutter e compilacao do backend.
- Revisar contrato de login, ausencia de `PORTAL_*` no bundle, compatibilidade do batch, documentacao de rotas e `git diff --check`.
- Relatar os comandos realmente executados; nao afirmar sucesso sem saida confirmatoria.
