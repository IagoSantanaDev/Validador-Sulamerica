import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/globals/widgets/icone_favicon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('favicon.ico embute um PNG 256x256 extraível e decodificável', () async {
    final ByteData dados = await rootBundle.load('web/favicon.ico');
    final Uint8List bytes = dados.buffer
        .asUint8List(dados.offsetInBytes, dados.lengthInBytes);

    final Uint8List png = IconeFavicon.extrairPng(bytes);

    // A imagem embutida deve ser PNG (assinatura padrão).
    expect(png.length, greaterThan(0));
    expect(
      png.sublist(0, 4),
      const [0x89, 0x50, 0x4E, 0x47],
      reason: 'esperava a assinatura PNG no payload do ICO',
    );

    final ui.Codec codec = await ui.instantiateImageCodec(png);
    final ui.FrameInfo frame = await codec.getNextFrame();
    expect(frame.image.width, greaterThan(0));
    expect(frame.image.height, greaterThan(0));
    expect(frame.image.width, 256);
    expect(frame.image.height, 256);
  });
}