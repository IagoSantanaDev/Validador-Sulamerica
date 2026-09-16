import 'procedimento.dart';

class GuiaTiss {
  const GuiaTiss({
    required this.numeroGuiaPrestador,
    required this.numeroCarteira,
    required this.senha,
    this.nomeBeneficiario,
    this.procedimentos = const [],
  });

  final String numeroGuiaPrestador;
  final String? numeroCarteira;
  final String? senha;
  final String? nomeBeneficiario;
  final List<Procedimento> procedimentos;
}
