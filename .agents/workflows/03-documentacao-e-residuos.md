# Workflow 03: Documentacao e residuos comprovados

## Objetivo

Alinhar documentacao/logs aos endpoints reais e remover apenas codigo comprovadamente sem uso. Seguir `.agents/AGENTS.md` e `.agents/workflows/00-orquestracao.md`.

## Arquivos sob propriedade exclusiva

- `README.md`
- `backend/README.md`
- `backend/bin/server.dart`
- `lib/modules/validador_xml/data/models/resultado_consulta_beneficiario.dart`, apenas se a busca global comprovar zero uso.

Nao edite outros arquivos de `lib/`, `test/` ou `backend/`. READMEs descrevem contrato comum, que deve seguir exatamente o especificado em workflow 00 e implementado pelas outras frentes.

## Resultado esperado

1. Compare cada rota e payload documentado com o router real. Remova referencias a endpoints inexistentes `/api/beneficiario` e `/api/autorizacao` se continuarem sem implementacao; documente `/api/login`, `/api/consultas` e `/api/status` com o contrato atualizado de login por `identificadorPrestador`.
2. Atualize instrucoes de deploy para configurar credenciais somente como secrets/environment variables do backend, nunca via `--dart-define` do Flutter nem valores em YAML versionado. Descreva identificadores aceitos apenas depois de confirmar o mapeamento de codigo; nao exponha identificadores pessoais desnecessarios.
3. Alinhe limites, recuperacao de sessao, TLS, CORS, topologia de instancia, comandos e exemplos com o comportamento real apos as outras mudancas. Nao documente seguranca TLS mais forte que a implementacao verificada.
4. Corrija o banner de rotas em `backend/bin/server.dart` para listar apenas rotas existentes.
5. Remova o modelo legado somente apos busca global de definicoes, imports, referencias textuais e geracao de codigo; preserve se existir qualquer consumidor. Nao remova testes ou arquivos por intuicao.

## Idempotencia

Leia os arquivos atuais e os resultados integrados das outras frentes antes de editar. Cada alteracao deve corrigir discrepancia verificavel. Se documentos, banner e referencias ja corresponderem ao codigo, ou se o modelo for usado, nao gere diff, invoque `/simple-commit` para confirmar que nao ha mudancas a commitar e reporte `ja satisfeito`/`mantido por uso`. Nao crie commit vazio; o coordenador confirma o estado em `KAN-08` e nao cria merge artificial.

## Validacao e encerramento

Confira todos os caminhos, comandos e exemplos contra os arquivos reais; procure mencoes de rotas antigas e variaveis `PORTAL_*` no README para assegurar que credenciais nao sao direcionadas ao frontend. Execute `git diff --check`; valide `dart analyze` se alterar `server.dart`. Limite de 500 LOC de producao alteradas continua valendo; docs nao contam.

Apos todos os checks passarem, invoque `/simple-commit` nesta worktree/branch exclusiva e confirme o push da branch do workflow. Entregue o SHA ao coordenador. O workflow so termina quando o coordenador integrar o SHA em `KAN-08` em serie, depois da conclusao das frentes paralelas, validar e publicar a branch principal. Em caso de bloqueio, nao commite nem tente contorna-lo; reporte claramente.
