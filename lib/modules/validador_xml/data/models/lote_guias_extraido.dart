import 'package:freezed_annotation/freezed_annotation.dart';

import 'guia_tiss.dart';
import 'informacoes_lote.dart';

part 'lote_guias_extraido.freezed.dart';

@freezed
abstract class LoteGuiasExtraido with _$LoteGuiasExtraido {
  const factory LoteGuiasExtraido({
    required InformacoesLote informacoes,
    required List<GuiaTiss> guias,
  }) = _LoteGuiasExtraido;
}
