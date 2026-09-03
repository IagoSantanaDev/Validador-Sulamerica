# Validador de Guias TISS — SulAmérica

Projeto Flutter Web para validar previamente um lote de guias TISS
(`guiaSP-SADT`) antes do envio à SulAmérica. Nesta fase, a interface e o
motor de regras estão prontos; a integração real com o portal passa por uma
**API intermediária** em `backend/` (contorna CORS e mantém a sessão do
portal no servidor).

## Como rodar

```bash
flutter create . --platforms web --org com.sulamerica --project-name validador_xml_sulamerica

flutter pub get
flutter test
flutter run -d chrome
```

## Sistema de requisições HTTP (Dio)

Infraestrutura genérica em `lib/globals/network/`, pronta para qualquer
datasource futuro (inclusive a integração real com a SulAmérica):

- `DioClient` — cliente único com baseUrl/timeouts centralizados,
  interceptors e métodos `get/post/put/patch/delete` que retornam
  `Result<T>` em vez de lançar exceção ou devolver `null`.
- `Result<T>` (`Success`/`Failure`) — Result pattern; use `.fold(...)`
  para tratar sucesso e erro.
- `AppException` — hierarquia de erro específica por causa
  (`SemConexaoException`, `RequisicaoExpiradaException`,
  `NaoAutorizadoException`, `RecursoNaoEncontradoException`,
  `ErroServidorException`, `ErroDesconhecidoException`), já mapeada a
  partir de `DioException` — datasources nunca lidam com Dio diretamente.
- `LoggingInterceptor` — loga apenas método/URL/status, nunca headers de
  autenticação nem corpo da requisição/resposta.
- `globals/service_locator.dart` — registra apenas `DioClient` no GetIt
  (`configurarDependenciasGlobais`), pois o container global não deve
  conhecer regra de negócio de módulo específico.
- `modules/validador_xml/data/services/validador_xml_service_locator.dart`
  — registra o `SulAmericaService` do módulo (`configurarDependenciasValidadorXml`).
  Ambos os registros são chamados em `main()` antes do `runApp`.

Exemplo de uso em um datasource futuro:

```dart
final resultado = await getIt<DioClient>().post<GuiaEnviada>(
  '/guias/lote',
  corpo: lotePayload,
  parser: (dados) => GuiaEnviada.fromJson(dados),
);

resultado.fold(
  onSuccess: (guia) => ...,
  onFailure: (erro) => ...,
);
```

Coberto por teste (`test/dio_client_test.dart`) usando um
`HttpClientAdapter` falso — sem chamada de rede real.

## Estrutura

```
lib/
  globals/                 # cores, dimensões, strings, tema e network compartilhados
  modules/validador_xml/
    data/
      models/               # GuiaTiss, ErroValidacao, GuiaValidada
      datasources/          # parsing do XML (xml package), sem regra de negócio
      repositories/
        regras/             # uma classe por regra (RegraValidacao), fácil de estender
    presentation/
      controllers/          # ValidadorController (ChangeNotifier / Provider)
      pages/                # ValidadorPage
      widgets/              # DropZoneWidget, ResultadoListaWidget, ErroGuiaCard
```

## Regras implementadas

- **senha obrigatória, deve começar com `5` e ter no máximo 10 caracteres** —
  `RegraSenhaPrefixo`. Ausência, prefixo inválido e tamanho excedido geram
  erros distintos.
- A autorização VPP pode ser consultada antes do login por
  `SulAmericaService.verificarSolicitacaoAutorizada`. A solicitação só é
  considerada autorizada quando `status_solicitacao.descricao` é `Autorizado`.
- Quando a senha não estiver disponível para a consulta ao beneficiário, o
  `numeroCarteira` continua sendo o valor alternativo.
- A carteirinha usada em `consultarBeneficiario` é dividida em segmentos de
  tamanho fixo (3-5-4-4-4 dígitos), não em cinco partes iguais — os
  segmentos têm tamanhos diferentes no número real (ex.: 582/01824/0043/
  8430/0010).
- Login e consulta postam para a `lumFormAction` de cada formulário
  (`saude.sulamericaseguros.com.br/main.jsp?lumPageId=...`), nunca para o
  domínio raiz — postar na raiz gera `ERR_CERT_COMMON_NAME_INVALID`.

Para adicionar uma nova regra: crie uma classe em
`data/repositories/regras/` implementando `RegraValidacao` e adicione-a à
lista padrão em `ValidadorGuiasRepositoryImpl` — nenhuma regra existente
precisa mudar.

## Exibição dos resultados

Cada ocorrência de `guiaSP-SADT` vira uma linha própria (nunca é mesclada
com outra). Linhas com o mesmo `numeroGuiaPrestador` são reordenadas para
ficarem sequenciais e recebem uma cor de fundo alternada, formando uma
sequência visual sem juntar tudo em uma única linha. Há um filtro
"Mostrar somente erros" e um resumo com total de guias e total com erro.

## Backend intermediário (proxy para o portal)

A integração real (login, consulta de beneficiário e autorização VPP) **não
pode ser feita direto do navegador**: validamos empiricamente que o portal não
envia `Access-Control-Allow-Origin` (CORS bloqueia a leitura) e que os cookies
de sessão são `SameSite=Strict`/`HttpOnly` (não trafegam cross-site). Além
disso, o endpoint `ajax-controller.jsp` de autorização VPP exige sessão
autenticada (sem login, responde 401).

A solução fica em `backend/` (Dart + shelf + dio/cookie_jar):
`POST /api/login`, `POST /api/beneficiario`, `GET /api/autorizacao?numeroVpp=`.
Veja `backend/README.md` para execução, variáveis de ambiente e detalhes.

Descobertas que afetam qualquer cliente HTTP (inclusive o `SulAmericaService`
do app — ainda precisa de ajustes):

- **GET inicial obrigatório**: o POST de login direto (sem visitar a página
  antes) retorna **403** — o F5 ASM exige o cookie `NSC_*` semeado no GET;
  o GET sem headers de navegador (`Accept`, `Accept-Language`,
  `Upgrade-Insecure-Requests`) também é barrado (500).
- **302 pós-submit**: o login autentica com 302 → `/prestador/`; a consulta
  de beneficiário responde 302 → `elegibilidade-resultado.htm`. O redirect
  precisa ser seguido via GET (com a sessão) para obter a página final.
- O `backend/` já implementa GET inicial + follow de redirect nas duas rotas.
