import 'package:freezed_annotation/freezed_annotation.dart';

import 'procedimento.dart';
import 'profissional_solicitante.dart';

part 'guia_tiss.freezed.dart';

@freezed
abstract class GuiaTiss with _$GuiaTiss {
  const factory GuiaTiss({
    required String numeroGuiaPrestador,
    required String? numeroCarteira,
    required String? senha,
    String? nomeBeneficiario,
    ProfissionalSolicitante? solicitante,
    @Default([]) List<Procedimento> procedimentos,
  }) = _GuiaTiss;
}
