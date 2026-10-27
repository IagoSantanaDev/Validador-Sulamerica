# Relatório de ingestão TUSS

- Gerado em: 2026-10-25T14:44:47.613068Z
- Data de referência para vigência: 2026-10-25
- Entrada: `Tabelas TUSS`
- Saída: `assets/tuss`

## Resumo

| Tabela | Snapshot | Arquivos | Itens | Duplicatas | Erros | Nomes vazios | Reparos nome | Reparos extras | Registros reparados | Sem extras | Bloco incompleto | Sem início | Sem fim (ausente) | Fim "-" | Fim no passado |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 18 | 20261025 | 1 | 3595 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 3595 | 0 |
| 19 | 20260526 | 31 | 1389786 | 0 | 0 | 0 | 304 | 50836 | 39943 | 16082 | 16082 | 16082 | 16083 | 1373703 | 0 |
| 20 | 20260525 | 1 | 43376 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 43376 | 0 |
| 22 | 20261023 | 1 | 5969 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 5967 | 0 |

## Arquivos por tabela

- 18: tuss-18_20261025.json
- 19: tuss-1920260526(1).json, tuss-1920260526(2).json, tuss-1920260526(3).json, tuss-1920260526(4).json, tuss-1920260526(5).json, tuss-1920260526(6).json, tuss-1920260526(7).json, tuss-1920260526(8).json, tuss-1920260526(9).json, tuss-1920260526(10).json, tuss-1920260526(11).json, tuss-1920260526(12).json, tuss-1920260526(13).json, tuss-1920260526(14).json, tuss-1920260526(15).json, tuss-1920260526(16).json, tuss-1920260526(17).json, tuss-1920260526(18).json, tuss-1920260526(19).json, tuss-1920260526(20).json, tuss-1920260526(21).json, tuss-1920260526(22).json, tuss-1920260526(23).json, tuss-1920260526(24).json, tuss-1920260526(25).json, tuss-1920260526(26).json, tuss-1920260526(27).json, tuss-1920260526(28).json, tuss-1920260526(29).json, tuss-1920260526(30).json, tuss-1920260526(31).json
- 20: tuss-2020260525(1).json
- 22: tuss-22_20261023.json

## Exemplos de reparo de dupla codificação

- 19: fabricante: E-MED PRODUTOS MÃ¿DICO-HOSPITALARES LTDA - ME -> E-MED PRODUTOS MÿDICO-HOSPITALARES LTDA - ME
- 19: fabricante: E-MED PRODUTOS MÃ¿DICO-HOSPITALARES LTDA - ME -> E-MED PRODUTOS MÿDICO-HOSPITALARES LTDA - ME
- 19: fabricante: E-MED PRODUTOS MÃ¿DICO-HOSPITALARES LTDA - ME -> E-MED PRODUTOS MÿDICO-HOSPITALARES LTDA - ME

Resíduos como `ÿ` (U+00FF) no texto reparado vêm de uma corrupção anterior, não da dupla codificação: o reparo desfaz apenas a camada comprovadamente reversível e mantém o restante como está.

## Divergências conhecidas

- Tabela 22: 5969 itens no snapshot e 5964 medidos na API; 5 sem reconciliação registrada.

## Invariantes verificados

- Contagem esperada por tabela.
- `id` presente, numérico, com 8 ou 9 dígitos e único.
- `source` igual a `tuss-<tabela>`.
- Datas de vigência em `AAAA-MM-DD` quando presentes.
- Snapshot único por tabela.
- Todos os arquivos da tabela com o mesmo snapshot.
