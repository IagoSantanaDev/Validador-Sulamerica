import 'package:freezed_annotation/freezed_annotation.dart';

part 'profissional_solicitante.freezed.dart';

@freezed
abstract class ProfissionalSolicitante with _$ProfissionalSolicitante {
  const factory ProfissionalSolicitante({
    String? numeroConselho,
  }) = _ProfissionalSolicitante;
}
