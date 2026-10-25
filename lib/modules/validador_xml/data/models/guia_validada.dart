import 'package:freezed_annotation/freezed_annotation.dart';

import 'consulta_guia.dart';
import 'erro_validacao.dart';
import 'guia_tiss.dart';

part 'guia_validada.freezed.dart';

@freezed
abstract class GuiaValidada with _$GuiaValidada {
  const factory GuiaValidada({
    required GuiaTiss guia,
    required List<ErroValidacao> erros,
    @Default([]) List<ConsultaGuia> consultas,
  }) = _GuiaValidada;

  const GuiaValidada._();

  bool get temErro => erros.isNotEmpty;

  bool get temFalhaConsulta => consultas.any((consulta) => !consulta.sucesso);

  ConsultaGuia? get consulta {
    if (consultas.isEmpty) return null;
    for (final ConsultaGuia consulta in consultas) {
      if (!consulta.sucesso) return consulta;
    }
    return consultas.first;
  }

  String get numeroGuiaPrestador => guia.numeroGuiaPrestador;
  String? get numeroCarteira => guia.numeroCarteira;
  String? get senha => guia.senha;
}
