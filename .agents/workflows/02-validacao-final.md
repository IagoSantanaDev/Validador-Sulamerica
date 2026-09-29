# 02 - Validacao integrada e auditoria final

## Dependencias e propriedade

Executar depois dos workflows 00 e 01. Este cartao e primariamente de leitura e verificacao. Nao modificar codigo; se encontrar defeito, reportar o arquivo/evidencia e abrir cartao de reparo limitado, sem corrigir de forma incidental.

## Checks

1. Na raiz, rode os testes focados XML/repository e service/controller/grade existentes ou criados; depois `flutter analyze` e `flutter test`.
2. Em `backend/`, rode os testes relacionados aos arquivos reorganizados, depois `dart analyze` e `dart test`.
3. Todos os checks devem usar fakes/adapters e nao podem chamar servicos externos.
4. Verifique que a extração XML preserva os modelos e regras existentes, e que os movimentos do backend nao alteraram comportamento, entrypoints ou contratos publicos.
5. Audite `git diff` real e status: limite de 500 linhas de producao por cartao; nenhum dado sensivel de teste; nenhum cache, build local ou arquivo transitorio adicionado; documentacao condiz com codigo.

## Context7 e relatorio

Use Context7 para auditar o diff real e registrar os riscos/compatibilidades; ele nao substitui testes locais. Se indisponivel, informe explicitamente que a auditoria Context7 ficou pendente. Nao alegue sucesso para checks nao executados.

Entregue uma tabela curta `check / resultado / observacao`, liste falhas por severidade com arquivo e linha, e declare qualquer bloqueio que impeça a entrega. Nao altere arquivos durante esta auditoria.