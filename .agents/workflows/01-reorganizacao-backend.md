# 01 - Reorganizar seletivamente o backend

## Dependencias e propriedade

Executar depois do workflow 00 e antes da validacao final. Reorganize apenas backend. O Flutter ja segue `lib/globals` e `lib/modules/validador_xml/{data,presentation}`; nao mova essa estrutura.

## Objetivo

Melhorar a organizacao por dominio do backend sem alterar comportamento ou contratos. Faça apenas movimentos justificados pela propriedade real apos a integracao.

## Regras

- Leia `.agents/AGENTS.md`, verifique todos os imports e entrypoints, e use a convencao modular existente no Flutter como referencia, sem impor pastas vazias ou uma camada generica artificial.
- Considere `sessao_portal.dart` e `elegibilidade_parser.dart` como candidatos a um modulo SulAmerica de dados. Mova `util_texto.dart` para utilitario compartilhado somente se consumidores reais de mais de um dominio justificarem. Mantenha `bin/server.dart` como entrypoint.
- Preserve a API package-level `package:validador_backend/validador_api.dart` usada pelo entrypoint/testes, usando fachada de compatibilidade se o arquivo de implementacao mudar de lugar.
- Cada movimento e pequeno e separado: verificar se destino ja existe; nunca sobrescrever; atualizar imports apenas do arquivo movido; sem renomeacao em massa, mudanca funcional, limpeza de debug ou refactor oportunista.
- Se uma execucao anterior ja moveu um arquivo e imports estao corretos, trate como sucesso/no-op. Se origem e destino coexistirem com conteudo diferente, pare para revisao manual.

## Teto e idempotencia

No maximo 500 linhas de producao alteradas por workflow. Fazer um movimento por execucao/cartao; movimentos puros devem ser detectaveis como rename no diff. Se o VCS contar o movimento como mais de 500 linhas alteradas ou o move exigir refactor, divida a tarefa e nao exceda o limite.

## Aceite

- Caminhos correspondem ao dominio; entrypoint e import package-level continuam funcionando.
- Nenhuma mudanca de comportamento, dependencia ou contrato publico.
- `dart analyze` e `dart test` em `backend/` passam apos cada movimento.
- Context7 pre-edicao e auditoria do diff real pos-edicao; consulte tambem convencoes locais de import.