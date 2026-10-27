import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// `AssetBundle` em memória, sem cache, para testar o carregamento dos
/// datasets TUSS.
class AssetBundleFake extends AssetBundle {
  AssetBundleFake(this.conteudos);

  final Map<String, String> conteudos;

  @override
  Future<ByteData> load(String key) async {
    final String? conteudo = conteudos[key];
    if (conteudo == null) {
      throw FlutterError('Asset não encontrado: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(conteudo)));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final String? conteudo = conteudos[key];
    if (conteudo == null) {
      throw FlutterError('Asset não encontrado: $key');
    }
    return conteudo;
  }
}
