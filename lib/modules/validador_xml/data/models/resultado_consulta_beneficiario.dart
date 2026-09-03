/// Resultado da consulta de beneficiário feita pelo backend intermediário.
///
/// [elegivel] e [rotuloElegibilidade] vêm da extração do
/// `elegibilidade-resultado.htm` feita pelo proxy: `true`/"SIM" ou
/// `false`/"NÃO" quando há resultado, e `null` quando o portal não renderiza
/// o bloco (carteira não encontrada — volta para a página de identificação).
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

  /// Texto bruto do `elegibilidade-resultado.htm` retornado pelo proxy.
  final String html;

  /// `true` para SIM, `false` para NÃO; `null` quando o portal não
  /// retornou o indicador (ex.: carteira não encontrada).
  final bool? elegivel;

  /// Rótulo cru extraído ("SIM", "NÃO" ou `null`).
  final String? rotuloElegibilidade;

  /// True quando a página de resultado contém o indicador de elegibilidade.
  bool get temResultadoElegibilidade => elegivel != null;
}