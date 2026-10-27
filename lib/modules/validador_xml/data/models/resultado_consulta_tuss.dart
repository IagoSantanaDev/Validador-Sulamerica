import 'package:freezed_annotation/freezed_annotation.dart';

import 'tuss_item.dart';

part 'resultado_consulta_tuss.freezed.dart';

/// Resultado da checagem de um código TUSS do XML.
///
/// `null` no classificador local significa que a tabela declarada é válida,
/// mas não tem base local: o código precisa ser consultado no proxy.
@freezed
sealed class ResultadoConsultaTuss with _$ResultadoConsultaTuss {
  const factory ResultadoConsultaTuss.encontrado({
    required TussItem item,
    required bool vigente,
  }) = TussEncontrado;

  const factory ResultadoConsultaTuss.naoEncontrado({
    required String codigo,
    required String tabela,
  }) = TussNaoEncontrado;

  const factory ResultadoConsultaTuss.tabelaDivergente({
    required String codigo,
    required String tabelaDeclarada,
    required String tabelaEncontrada,
  }) = TussTabelaDivergente;

  const factory ResultadoConsultaTuss.semReferencia({
    required String codigo,
    required String tabela,
  }) = TussSemReferencia;

  const factory ResultadoConsultaTuss.tabelaDesconhecida({
    required String codigo,
    required String tabela,
  }) = TussTabelaDesconhecida;

  const factory ResultadoConsultaTuss.indisponivel({
    required String codigo,
    required String tabela,
    required String motivo,
  }) = TussIndisponivel;
}
