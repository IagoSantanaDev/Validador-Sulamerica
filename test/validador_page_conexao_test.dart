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

  testWidgets('API indisponível não bloqueia a seleção de XML', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ValidadorPage()));
    await tester.pump();

    expect(find.text(AppStrings.apiIndisponivelTitulo), findsOneWidget);
    expect(find.text(AppStrings.apiTentarNovamente), findsOneWidget);
    expect(find.text(AppStrings.apiVerificandoTitulo), findsNothing);
    expect(find.text(AppStrings.dropZoneTexto), findsOneWidget);
  });
}
