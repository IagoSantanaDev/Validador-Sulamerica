# Validador de Guias TISS — SulAmérica (fase 1: interface + regras locais)

Projeto Flutter Web para validar previamente um lote de guias TISS
(`guiaSP-SADT`) antes do envio à SulAmérica. Nesta fase ainda não há
integração com o site — o foco é a interface e o motor de regras.

## Como rodar (no seu ambiente WSL2/Windows)

Este código foi escrito no meu ambiente de sandbox, que **não tem o Flutter
SDK instalado nem acesso a pub.dev**, então não consegui rodar
`flutter pub get` / `flutter run` / os testes aqui. Vale rodar essa
validação no seu WSL2 antes de considerar pronto:

```bash
flutter create . --platforms web --org com.sulamerica --project-name validador_xml_sulamerica
# (isso preenche android/ios/etc. que removi daqui; sobrescreva lib/, web/index.html,
# pubspec.yaml, test/ e analysis_options.yaml com os deste projeto se o comando pedir)

flutter pub get
flutter test
flutter run -d chrome
```

Se preferir não rodar `flutter create`, basta garantir que exista uma pasta
`web/` completa (o `flutter create --platforms web` gera os demais arquivos
de bootstrap que não incluí, como `flutter_bootstrap.js`, ícones e manifest).

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
- `service_locator.dart` — registra `DioClient` no GetIt via
  `configurarDependenciasGlobais(baseUrlPadrao: '...')`. Chame isso no
  `main()` quando a baseUrl real da SulAmérica for definida; por ora não
  foi conectado a nada, para não introduzir configuração especulativa.

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

- **numeroCarteira obrigatório e deve começar com `5`** — `RegraNumeroCarteiraPrefixo`.
  Se vazio ou não começar com 5, a guia é marcada com erro.

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

## Pendências conhecidas para a próxima fase

- Integração real com o site da SulAmérica (autenticação, envio).
- Cobertura de outros tipos de guia além de `guiaSP-SADT`
  (`guiaConsulta`, `guiaResumoInternacao`, etc.), se necessário.
- Rodar `flutter pub get` / `flutter test` localmente para confirmar que
  compila (não validado neste ambiente por falta de SDK/rede).
