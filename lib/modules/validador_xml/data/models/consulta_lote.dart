import 'package:freezed_annotation/freezed_annotation.dart';

import 'consulta_guia.dart';

part 'consulta_lote.freezed.dart';

@freezed
abstract class ConsultaLoteItem with _$ConsultaLoteItem {
  const factory ConsultaLoteItem({
    required TipoConsultaGuia tipo,
    required String chave,
  }) = _ConsultaLoteItem;
}

@freezed
abstract class ResultadoConsultaLote with _$ResultadoConsultaLote {
  const factory ResultadoConsultaLote({
    required String chave,
    required TipoConsultaGuia tipo,
    required bool sucesso,
    bool? elegivel,
    String? rotuloElegibilidade,
    String? statusSenha,
    String? erro,
  }) = _ResultadoConsultaLote;

  static ResultadoConsultaLote fromJson(Map<String, dynamic> json) {
    final String tipo = json['tipo'] as String? ?? '';
    return ResultadoConsultaLote(
      chave: json['chave'] as String? ?? '',
      tipo: tipo == 'senha'
          ? TipoConsultaGuia.senha
          : TipoConsultaGuia.elegibilidade,
      sucesso: json['sucesso'] as bool? ?? false,
      elegivel: json['elegivel'] as bool?,
      rotuloElegibilidade: json['rotuloElegibilidade'] as String?,
      statusSenha: json['statusSenha'] as String?,
      erro: json['erro'] as String?,
    );
  }
}
