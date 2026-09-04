class GuiaTiss {
  const GuiaTiss({
    required this.numeroGuiaPrestador,
    required this.numeroCarteira,
    required this.senha,
    this.nomeBeneficiario,
  });

  final String numeroGuiaPrestador;
  final String? numeroCarteira;
  final String? senha;
  final String? nomeBeneficiario;
}