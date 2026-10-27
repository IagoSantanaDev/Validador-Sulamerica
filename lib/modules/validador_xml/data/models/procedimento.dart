import 'package:freezed_annotation/freezed_annotation.dart';

part 'procedimento.freezed.dart';

@freezed
abstract class Procedimento with _$Procedimento {
  const factory Procedimento({
    required String codigo,
    required int quantidade,
    String? codigoTabela,
    String? dataExecucao,
  }) = _Procedimento;
}
