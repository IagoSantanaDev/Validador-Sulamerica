import 'consulta_guia.dart';
import 'erro_validacao.dart';
import 'guia_tiss.dart';

class GuiaValidada {
  const GuiaValidada({
    required this.guia,
    required this.erros,
    this.consulta,
  });

  final GuiaTiss guia;
  final List<ErroValidacao> erros;

  /// Resultado da consulta ao portal (elegibilidade/autorização VPP), quando
  /// configurado; nulo quando a guia não foi consultada.
  final ConsultaGuia? consulta;

  bool get temErro => erros.isNotEmpty;
  String get numeroGuiaPrestador => guia.numeroGuiaPrestador;
  String? get numeroCarteira => guia.numeroCarteira;
  String? get senha => guia.senha;
}