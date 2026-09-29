# Workflow 02: Frontend e validacao resiliente

## Objetivo

Remover segredos do cliente e corrigir validacao, lote e estado de sessao no Flutter Web. Seguir `.agents/AGENTS.md` e `.agents/workflows/00-orquestracao.md`.

## Arquivos sob propriedade exclusiva

- `lib/**`, exceto `lib/modules/validador_xml/data/models/resultado_consulta_beneficiario.dart`, reservado ao workflow de documentacao/residuos.
- `test/**`
- Configuracao de build Flutter estritamente necessaria.

Nao edite `backend/`, READMEs ou o modelo reservado. Nao toque nos mesmos arquivos em worktrees de outros agentes.

## Resultado esperado

1. **Contrato sem segredos:** o frontend envia apenas `{identificadorPrestador}` para login. Remova `PORTAL_CODE_*`, `PORTAL_USER_*` e `PORTAL_SENHA_*` do bundle, `AppConfig`, `--dart-define`, logs e artefatos publicados. Preserve o mapeamento de identificador do prestador sem incluir segredo. O contrato e congelado no workflow 00; se o backend nao o implementar, bloqueie a integracao em vez de inventar um segundo contrato.
2. **Formato da senha:** senha valida tem exatamente 10 caracteres numericos ASCII e comeca com `5`. Use a mesma regra na validacao local e antes da consulta. Adicione casos para letras, pontuacao, espacos, Unicode numerico, comprimento incorreto e valores validos.
3. **Lotes grandes:** preserve deduplicacao por `tipo|chave`, divida chamadas de forma que cada requisicao contenha no maximo 300 itens, recomponha resultados por chave e anexe-os a todas as guias correspondentes sem perder ordem nem duplicatas. Trate lotes parciais/falhas explicitamente; nao interprete resposta ausente como sucesso.
4. **Sessao:** quando o backend rejeitar token/sessao com 401/403, refaca login pelo novo contrato e tente o batch uma vez. Evite loops de reautenticacao e mantenha erros apresentados por guia. Verifique se a API ja recupera sessao portal internamente antes de adicionar retry duplicado.
5. **XML/performance:** o controller extrai metadados e o repositorio pode parsear o mesmo XML de novo. Reduza parsing duplicado usando o menor ajuste compativel com contratos e testes. Avalie Context7 para Flutter Web/Dart antes de mover trabalho para isolate; mantenha a UI responsiva sem assumir que APIs de isolate do VM se comportam igual no Web. Se o ganho nao justificar a complexidade, documente e mantenha o parse unico.
6. **Testes:** adicione cobertura de senha, particionamento em mais de 300 chaves, correlacao/repeticao de chaves, token rejeitado e comportamento de parse/metadados. Siga os doubles e convencoes existentes em `test/`.

## Idempotencia

Inspecione codigo e testes antes de alterar. Mantenha batching, deduplicacao, regras ou recuperacao ja presentes. Se o resultado esperado estiver satisfeito e testado, declare `ja satisfeito` sem diff e invoque `/simple-commit` para confirmar que nao ha mudancas a commitar. Nao crie commit vazio; o coordenador confirma o estado em `KAN-08` e nao cria merge artificial.

## Validacao e encerramento

Execute `flutter analyze` e `flutter test` na raiz, mais testes focados. Se houver mudanca em processamento Web, rode build web quando viavel. Inspecione bundle de producao com busca por nomes/valores de credenciais sem exibir valores; confira ownership e limite de ate 500 LOC de producao (linhas adicionadas + removidas; testes e docs nao contam).

Apos todos os checks passarem, invoque `/simple-commit` nesta worktree/branch exclusiva e confirme o push da branch do workflow. Entregue o SHA ao coordenador. O workflow so termina quando o coordenador integrar o SHA em `KAN-08` em serie, depois da conclusao das frentes paralelas, validar e publicar a branch principal. Em caso de bloqueio, nao commite nem tente contorna-lo; reporte claramente.
