import 'package:freezed_annotation/freezed_annotation.dart';

part 'consulta_guia.freezed.dart';

enum TipoConsultaGuia { elegibilidade, senha }

@freezed
abstract class ConsultaGuia with _$ConsultaGuia {
  const factory ConsultaGuia({
    required bool sucesso,
    required String descricao,
    @Default(TipoConsultaGuia.elegibilidade) TipoConsultaGuia tipo,
  }) = _ConsultaGuia;
}
