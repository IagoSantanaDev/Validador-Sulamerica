import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IconeFavicon extends StatelessWidget {
  const IconeFavicon({super.key, this.tamanho = 40});

  final double tamanho;

  static Future<ui.Image>? _imagemCache;

  static Future<ui.Image> _carregar() {
    return _imagemCache ??= _decodificarFavicon();
  }

  static Future<ui.Image> _decodificarFavicon() async {
    final ByteData dados = await rootBundle.load('web/favicon.ico');
    final Uint8List bytes =
        dados.buffer.asUint8List(dados.offsetInBytes, dados.lengthInBytes);

    final ui.Codec codec = await ui.instantiateImageCodec(extrairPng(bytes));
    final ui.FrameInfo frame = await codec.getNextFrame();
    return frame.image;
  }

  static Uint8List extrairPng(Uint8List bytes) {
    final ByteData view = ByteData.sublistView(bytes);
    final int count = view.getUint16(4, Endian.little);

    int melhorArea = 0;
    int melhorIndice = -1;
    for (int i = 0; i < count; i++) {
      final int off = 6 + i * 16;
      final int largura = bytes[off] == 0 ? 256 : bytes[off];
      final int altura = bytes[off + 1] == 0 ? 256 : bytes[off + 1];
      final int area = largura * altura;
      if (area > melhorArea) {
        melhorArea = area;
        melhorIndice = i;
      }
    }
    if (melhorIndice < 0) {
      throw const FormatException('ICO sem direntries.');
    }

    final int off = 6 + melhorIndice * 16;
    final int tamImagem = view.getUint32(off + 8, Endian.little);
    final int offImagem = view.getUint32(off + 12, Endian.little);
    return Uint8List.sublistView(
      bytes,
      offImagem,
      offImagem + tamImagem,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.Image>(
      future: _carregar(),
      builder: (context, snapshot) {
        final ui.Image? imagem = snapshot.data;
        if (imagem == null) {
          return SizedBox(
            width: tamanho,
            height: tamanho,
          );
        }
        return RawImage(
          image: imagem,
          width: tamanho,
          height: tamanho,
          fit: BoxFit.contain,
        );
      },
    );
  }
}
