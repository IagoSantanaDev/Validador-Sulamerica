import 'consulta_guia.dart';
import 'erro_validacao.dart';
import 'guia_tiss.dart';

class GuiaValidada {
  const GuiaValidada({
    required this.guia,
    required this.erros,
    this.consultas = const [],
  });

  final GuiaTiss guia;
  final List<ErroValidacao> erros;

  final List<ConsultaGuia> consultas;

  bool get temErro => erros.isNotEmpty;

  bool get temFalhaConsulta => consultas.any((c) => !c.sucesso);

  ConsultaGuia? get consulta {
    if (consultas.isEmpty) return null;
    for (final ConsultaGuia c in consultas) {
      if (!c.sucesso) return c;
    }
    return consultas.first;
  }

  String get numeroGuiaPrestador => guia.numeroGuiaPrestador;
  String? get numeroCarteira => guia.numeroCarteira;
  String? get senha => guia.senha;
}
