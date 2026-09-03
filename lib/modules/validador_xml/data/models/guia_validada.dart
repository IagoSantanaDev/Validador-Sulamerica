import 'erro_validacao.dart';
import 'guia_tiss.dart';

/// Resultado da aplicação das regras de validação sobre uma [GuiaTiss].
class GuiaValidada {
  const GuiaValidada({
    required this.guia,
    required this.erros,
  });

  final GuiaTiss guia;
  final List<ErroValidacao> erros;

  bool get temErro => erros.isNotEmpty;
  String get numeroGuiaPrestador => guia.numeroGuiaPrestador;
  String? get numeroCarteira => guia.numeroCarteira;
}
