import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:validador_xml_sulamerica/globals/constants/app_strings.dart';
import 'package:validador_xml_sulamerica/globals/network/dio_client.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/services/sul_america_backend_service.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/presentation/pages/validador_page.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/presentation/widgets/drop_zone_site.dart';

class _AdapterStatusPendente implements HttpClientAdapter {
  final Completer<ResponseBody> resposta = Completer<ResponseBody>();

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return resposta.future;
  }
}

class _AdapterStatusSequencial implements HttpClientAdapter {
  _AdapterStatusSequencial(this.respostas);

  final List<Future<ResponseBody>> respostas;
  int _indice = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respostas[_indice++];
}

ResponseBody _respostaStatus({
  required bool bloqueado,
  int retryAfterSegundos = 0,
}) {
  return ResponseBody.fromBytes(
    utf8.encode(
      '{"status":"ok","bloqueio":{"ativo":$bloqueado,'
      '"motivo":"limite_portal","codigo":"429",'
      '"mensagem":"Limite de consultas do portal atingido (429)",'
      '"retryAfterSegundos":$retryAfterSegundos}}',
    ),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  testWidgets('oculta a dropzone enquanto verifica a conexão', (
    WidgetTester tester,
  ) async {
    final GetIt getIt = GetIt.instance;
    final _AdapterStatusPendente adapter = _AdapterStatusPendente();
    final Dio dio = Dio()..httpClientAdapter = adapter;
    getIt.registerSingleton<SulAmericaBackendService>(
      SulAmericaBackendService(
        DioClient(baseUrl: 'http://localhost', dio: dio),
      ),
    );
    addTearDown(() => getIt.reset());

    await tester.pumpWidget(const MaterialApp(home: ValidadorPage()));
    await tester.pump();

    expect(find.text(AppStrings.apiVerificandoTitulo), findsOneWidget);
    expect(find.text(AppStrings.apiIndisponivelTitulo), findsNothing);
    expect(find.text(AppStrings.apiTentarNovamente), findsNothing);
    expect(find.text(AppStrings.dropZoneTexto), findsNothing);

    adapter.resposta.complete(
      ResponseBody.fromBytes(
        utf8.encode('{"status":"ok"}'),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.apiVerificandoTitulo), findsNothing);
    expect(find.text(AppStrings.dropZoneTexto), findsOneWidget);
  });

  testWidgets('oculta a dropzone quando a API está indisponível', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ValidadorPage()));
    await tester.pump();

    expect(find.text(AppStrings.apiIndisponivelTitulo), findsOneWidget);
    expect(find.text(AppStrings.apiTentarNovamente), findsOneWidget);
    expect(find.text(AppStrings.apiVerificandoTitulo), findsNothing);
    expect(find.text(AppStrings.dropZoneTexto), findsNothing);
  });

  testWidgets('mostra causa e contagem regressiva do bloqueio global', (
    WidgetTester tester,
  ) async {
    final GetIt getIt = GetIt.instance;
    final _AdapterStatusPendente adapter = _AdapterStatusPendente();
    final Dio dio = Dio()..httpClientAdapter = adapter;
    getIt.registerSingleton<SulAmericaBackendService>(
      SulAmericaBackendService(
        DioClient(baseUrl: 'http://localhost', dio: dio),
      ),
    );
    addTearDown(() => getIt.reset());

    await tester.pumpWidget(const MaterialApp(home: ValidadorPage()));
    await tester.pump();
    adapter.resposta.complete(
      ResponseBody.fromBytes(
        utf8.encode(
          '{"status":"ok","bloqueio":{"ativo":true,'
          '"motivo":"limite_portal","codigo":"429",'
          '"mensagem":"Limite de consultas do portal atingido (429)",'
          '"retryAfterSegundos":90}}',
        ),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    await tester.pumpAndSettle();

    final Finder tituloBloqueio = find.text(
      'Consultas temporariamente bloqueadas (429)',
    );
    expect(tituloBloqueio, findsOneWidget);
    expect(find.textContaining('01:30'), findsOneWidget);
    expect(find.text(AppStrings.dropZoneTexto), findsNothing);
    expect(
      tester.getTopLeft(tituloBloqueio).dy,
      greaterThan(tester.getTopLeft(find.text(AppStrings.jumbotronLegenda)).dy),
    );
  });

  testWidgets('revalida o mesmo XML após um bloqueio interromper a validação', (
    WidgetTester tester,
  ) async {
    final GetIt getIt = GetIt.instance;
    final Completer<ResponseBody> validacaoAposBloqueio =
        Completer<ResponseBody>();
    final _AdapterStatusSequencial adapter = _AdapterStatusSequencial([
      Future.value(_respostaStatus(bloqueado: false)),
      Future.value(_respostaStatus(bloqueado: false)),
      Future.value(
        _respostaStatus(bloqueado: true, retryAfterSegundos: 1),
      ),
      Future.value(_respostaStatus(bloqueado: false)),
      Future.value(_respostaStatus(bloqueado: false)),
      validacaoAposBloqueio.future,
    ]);
    final Dio dio = Dio()..httpClientAdapter = adapter;
    getIt.registerSingleton<SulAmericaBackendService>(
      SulAmericaBackendService(
        DioClient(baseUrl: 'http://localhost', dio: dio),
      ),
    );
    addTearDown(() => getIt.reset());

    await tester.pumpWidget(const MaterialApp(home: ValidadorPage()));
    await tester.pumpAndSettle();

    DropZoneSite dropzone = tester.widget(find.byType(DropZoneSite));
    dropzone.onArquivoSelecionado(
      'lote.xml',
      Uint8List.fromList('<mensagemTISS/>'.codeUnits),
    );
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      find.text('Consultas temporariamente bloqueadas (429)'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(DropZoneSite), findsOneWidget);

    dropzone = tester.widget(find.byType(DropZoneSite));
    dropzone.onArquivoSelecionado(
      'lote.xml',
      Uint8List.fromList('<mensagemTISS/>'.codeUnits),
    );
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text(AppStrings.verificandoDisponibilidade), findsOneWidget);
    expect(adapter._indice, 6);
  });
}
