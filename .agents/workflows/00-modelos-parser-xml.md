# 00 - Centralizar os modelos e a extracao XML

## Dependencias e propriedade

Propriedade de producao limitada a `lib/modules/validador_xml/data/datasources/xml_lote_guias_datasource.dart` e modelos de lote/guia diretamente necessarios. Nao altere controller, service HTTP, pagina, grade ou backend.

## Objetivo

Usar os modelos e caminhos de dados descritos em `debug/KAN-08/Validador XML/Estrutura dos models.txt` para centralizar a leitura do documento e extrair metadados e guias do mesmo parse, sem mudar os valores usados pelas regras existentes.

## Regras

- Inspecione o datasource, modelos, consumidores e testes existentes antes de projetar a API. Preserve compatibilidade dos metodos publicos existentes ou atualize todos os consumidores dentro deste escopo.
- Preserve a estrategia namespace-agnostic existente baseada em nome local e confirme-a com a documentacao atual do pacote `xml` usado pelo projeto (`^6.5.0`) via Context7 antes de editar. Se Context7 nao localizar esse pacote, nao invente APIs: use a API ja presente no datasource e declare a limitacao no relatorio.
- Mantenha os campos e valores literais intencionais de `GuiaTiss`, `Procedimento`, `ProfissionalSolicitante`, `InformacoesLote` e `GuiaValidada`. Nao normalizar senha, carteira, conselho ou codigo de procedimento sem requisito explicito.
- Preserve a nulabilidade e o comportamento dos metadados opcionais existentes. XML malformado e ausencia de guias devem permanecer distinguiveis; o datasource nao deve converter silenciosamente XML malformado em `InformacoesLote.vazio` quando isso impedir a validacao segura.
- Mantenha o escopo restrito a parse e modelos XML; nao adicione consultas de rede nem regras de negocio externas ao documento.

## Teto e idempotencia

Maximo de 500 linhas de producao alteradas; testes/fixtures nao contam. Reexecute verificando primeiro a API e os testes existentes; nao crie um segundo parser/modelo se uma execucao anterior ja centralizou essa responsabilidade.

## Testes e aceite

- Adicione/ajuste testes para XMLs de exemplo, prefixos `ans` e `tiss`, namespace default, metadados previstos nos modelos, multiplas guias e XML malformado. Nao dependa de arquivos sensiveis nem de rede.
- Prove que metadados e guias representam o mesmo documento e que os valores ja consumidos pelas regras nao mudaram.
- Rode os testes focados do datasource e repository e `flutter analyze`.
- Consulte Context7 antes da alteracao e audite o diff real depois; execute os checks nativos acima. Se o limite for excedido ou algum consumidor externo exigir mudanca fora deste escopo, pare e reporte.