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

  /// Resultados das consultas ao portal para esta guia (elegibilidade e/ou
  /// autorização VPP) — a guia pode ter até duas consultas; nula nas guias
  /// não consultadas.
  final List<ConsultaGuia> consultas;

  bool get temErro => erros.isNotEmpty;

  /// Há alguma consulta ao portal que falhou (elegível NÃO, senha inválida,
  /// autorização negada, erro de transporte, etc.).
  bool get temFalhaConsulta => consultas.any((c) => !c.sucesso);

  /// Primeira consulta com falha; se nenhuma falhou, a primeira consulta;
  /// null quando a guia não foi consultada. A visão completa fica em
  /// [consultas] (elegibilidade + autorização).
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
