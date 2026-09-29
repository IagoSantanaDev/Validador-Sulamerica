# Workflows de implementacao KAN-08

Execute um workflow por subagente, respeitando a ordem abaixo. Os workflows sao prompts de trabalho e nao autorizam chamadas a servicos externos.

## Ordem

```text
00-modelos-parser-xml
       |
01-reorganizacao-backend
       |
02-validacao-final
```

Execute na ordem ilustrada. Nao rode tarefas em paralelo; a validacao final deve ser a ultima.

## Cartoes

- [00 - Modelos e parser XML](00-modelos-parser-xml.md): centralizar a extração e preservar os modelos e regras existentes.
- [01 - Reorganizacao backend](01-reorganizacao-backend.md): movimentos seletivos sem alteracao comportamental.
- [02 - Validacao final](02-validacao-final.md): auditoria do diff e verificacoes integradas, por ultimo.

## Regras comuns

- Cada workflow de implementacao pode alterar no maximo 500 linhas de codigo de producao. Testes e fixtures nao contam. Se o escopo exceder o limite, pare e proponha dividir o cartao; nao entregue parcialmente como se estivesse concluido.
- Antes de editar, inspecione o estado atual do worktree e os arquivos proprietarios. Reexecucoes devem detectar trabalho ja aplicado, reutilizar o que existe e nao duplicar arquivos, simbolos, rotas, mensagens ou variaveis. Nunca sobrescreva alteracoes do usuario.
- Nao copie dados pessoais, credenciais ou outros valores sensiveis dos anexos de debug para codigo, workflows ou fixtures.
- Nenhum teste, analise ou build pode chamar servicos externos. Injete dependencias e use fakes/adapters deterministicos.
- Em cada mudanca de codigo, consulte Context7 antes de editar e depois audite o diff real. Use tambem os checks nativos indicados no cartao. Se Context7 estiver indisponivel, nao alegue que o gate passou; pare antes da edicao e reporte o bloqueio.
- Leia `.agents/AGENTS.md` e siga suas regras de reutilizacao, arquitetura, seguranca, validacao e higiene.
- Resolva apenas as alteracoes de producao do cartao atual; testes correspondentes fazem parte do trabalho e nao entram no limite de 500 linhas.