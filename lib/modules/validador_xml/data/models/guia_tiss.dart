import 'procedimento.dart';
import 'profissional_solicitante.dart';

class GuiaTiss {
  const GuiaTiss({
    required this.numeroGuiaPrestador,
    required this.numeroCarteira,
    required this.senha,
    this.nomeBeneficiario,
    this.solicitante,
    this.procedimentos = const [],
  });

  final String numeroGuiaPrestador;
  final String? numeroCarteira;
  final String? senha;
  final String? nomeBeneficiario;
  final ProfissionalSolicitante? solicitante;
  final List<Procedimento> procedimentos;
}
