# Ingestão TUSS

Gera os datasets compactos consumidos pelo app a partir dos JSONs brutos da API
TUSS da ANS. Os JSONs brutos não entram no repositório.

## Comando

```bash
dart run tool/tuss_ingestao.dart --entrada "C:\caminho\Tabelas TUSS" --hoje 2026-10-25
```

Opções:

- `--entrada`: pasta com os arquivos `tuss-<n>*.json` (obrigatória).
- `--saida`: pasta dos datasets. Padrão `assets/tuss`.
- `--relatorio`: caminho do relatório. Padrão `tool/relatorios/tuss-ingestao.md`.
- `--hoje`: data de referência para contar `fim_vigencia` no passado.

## O que é gerado

- `assets/tuss/tuss-18.json`, `tuss-20.json`, `tuss-22.json`: datasets com `id`,
  `nome`, `inicioVigencia` e `fimVigencia`.
- `assets/tuss/manifest.json`: snapshot, arquivos de origem, contagem e SHA-256
  de cada dataset.
- `tool/relatorios/tuss-ingestao.md`: contagens, invariantes, reparos e
  divergências conhecidas.

A tabela 19 é validada e contada, mas não gera dataset: ela é consultada por
código na API, via backend, por causa do volume (1.389.786 itens).

## Invariantes

O script falha, sem substituir os datasets anteriores, quando encontra:

- tabela esperada ausente;
- contagem diferente da esperada;
- `id` ausente, não numérico, com tamanho diferente de 8 ou 9 dígitos, ou
  duplicado;
- `source` diferente de `tuss-<tabela>`;
- data de vigência fora de `AAAA-MM-DD`;
- snapshots diferentes entre arquivos da mesma tabela;
- nome de arquivo `tuss-*` não reconhecido.

## Dupla codificação

Um texto é reparado apenas quando `latin1.encode` seguido de `utf8.decode`
funciona e muda o conteúdo. O relatório conta campos e registros reparados por
tabela. Texto que não forma sequência UTF-8 válida é mantido como está.

O reparo desfaz só a camada comprovadamente reversível. Quando o resultado ainda
traz resíduo de mojibake, como `ÿ` (U+00FF) em `MÃ¿DICO` → `MÿDICO`, a corrupção
é anterior e não é recuperável por regra mecânica. Esses casos aparecem na tabela
19, que não é embarcada no app.

## Atualizar o snapshot

1. Baixe os arquivos novos para uma pasta fora do repositório.
2. Atualize `_contagensEsperadasPadrao` e `_totalApiMedido` em
   `tool/tuss/src/ingestao_tuss.dart` com as contagens medidas.
3. Rode o comando com `--hoje` igual à data da análise.
4. Confira o relatório e os hashes no `manifest.json`.
5. Rode `flutter test` e `flutter analyze`.
