class ResultadoConsultaBeneficiario {
  const ResultadoConsultaBeneficiario({
    this.elegivel,
    this.rotuloElegibilidade,
  });

  factory ResultadoConsultaBeneficiario.fromJson(
    Map<String, dynamic> json,
  ) {
    return ResultadoConsultaBeneficiario(
      elegivel: json['elegivel'] as bool?,
      rotuloElegibilidade: json['rotuloElegibilidade'] as String?,
    );
  }

  final bool? elegivel;
  final String? rotuloElegibilidade;

  bool get temResultadoElegibilidade => elegivel != null;
}