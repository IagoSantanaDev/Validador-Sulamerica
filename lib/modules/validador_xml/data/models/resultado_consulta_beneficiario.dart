class ResultadoConsultaBeneficiario {
  const ResultadoConsultaBeneficiario({
    required this.html,
    this.elegivel,
    this.rotuloElegibilidade,
  });

  factory ResultadoConsultaBeneficiario.fromJson(
    Map<String, dynamic> json,
  ) {
    return ResultadoConsultaBeneficiario(
      elegivel: json['elegivel'] as bool?,
      rotuloElegibilidade: json['rotuloElegibilidade'] as String?,
      html: json['html'] as String? ?? '',
    );
  }

  final String html;
  final bool? elegivel;
  final String? rotuloElegibilidade;

  bool get temResultadoElegibilidade => elegivel != null;
}