# Workflow 01: API, sessao e seguranca

## Objetivo

Corrigir os riscos do backend da API intermediaria sem alterar o frontend ou a documentacao. Seguir `.agents/AGENTS.md` e o protocolo `.agents/workflows/00-orquestracao.md`.

## Arquivos sob propriedade exclusiva

- `backend/lib/validador_api.dart`
- `backend/lib/modules/sulamerica/data/sessao_portal.dart`
- Configuracao de deploy do backend estritamente necessaria para secrets, somente apos inspecionar o provider.
- `backend/test/**`

Nao edite `lib/`, `test/`, READMEs ou `backend/bin/server.dart`. Nao toque nos mesmos arquivos em worktrees de outros agentes.

## Resultado esperado

1. **Credenciais:** login recebe apenas `identificadorPrestador`. O backend resolve as credenciais no servidor por uma fonte de secrets/configuracao adequada ao deploy e rejeita identificadores desconhecidos. Nunca loga credenciais. Preserve resposta `{token, autenticada: true}` e o fluxo de sessoes extras. Nao coloque valores reais em codigo, YAML, exemplos executaveis ou testes.
2. **TLS:** verifique a documentacao Context7 de Dart/Dio 5 e o comportamento real do portal. Substitua qualquer aceitacao cega por hostname por validacao da cadeia/CA ou pinning apropriado, com teste possivel e procedimento de rotacao. Se o portal exigir workaround sem alternativa segura confirmada, nao reduza seguranca silenciosamente: pare e reporte a evidenca e a decisao necessaria.
3. **Payloads:** valide tipos, formatos, comprimentos e valores de cada item antes de qualquer cast/consulta externa. JSON malformado ou estruturas invalidas devem retornar status e erro previsiveis, sem HTTP 500 acidental. Mantenha o limite de 300 itens e 1 MB.
4. **Rate limit:** confirme como o Render/proxy configura IP de origem. Nao confie em `X-Forwarded-For` arbitrario recebido do cliente; aceite apenas header normalizado por proxy confiavel ou use endereco de conexao. Evite armazenamento de janelas por IP sem limite/expiracao. Preserve comportamento em falhas e testes.
5. **Ciclo de vida:** feche recursos de sessoes quando forem evictados, substituidos ou falharem. Mantenha credenciais/token alinhados e sem reter segredos alem da necessidade.
6. **Testes:** cubra login por identificador desconhecido/conhecido sem credenciais na requisicao, payload invalido, rate limit e trusted proxy quando testavel, certificado valido/invalido quando isolavel, e encerramento de sessao. Adapte ao padrao existente em `backend/test/`.

## Idempotencia

Antes de editar, inspecione os arquivos e testes. Reutilize comportamentos ja corretos; nao replique limites ou validacoes existentes. Se o estado esperado estiver todo presente e coberto, declare `ja satisfeito`, nao altere arquivos e siga `/simple-commit` para confirmar que nao ha mudancas a commitar. Nao crie commit vazio; o coordenador confirma o estado em `KAN-08` e nao cria merge artificial.

## Validacao e encerramento

Execute `dart analyze` e `dart test` dentro de `backend/`; execute testes focados adicionais conforme a mudanca. Verifique diff, propriedade de arquivos, secrets e limite de ate 500 LOC de producao (linhas adicionadas + removidas; testes/config de teste nao contam).

Apos todos os checks passarem, invoque `/simple-commit` nesta worktree/branch exclusiva e confirme o push da branch do workflow. Entregue o SHA ao coordenador. O workflow so termina quando o coordenador integrar o SHA em `KAN-08` em serie, apos as demais frentes paralelas terminarem, validar e publicar a branch principal. Em caso de qualquer bloqueio, nao commite nem tente contorna-lo; reporte claramente.
