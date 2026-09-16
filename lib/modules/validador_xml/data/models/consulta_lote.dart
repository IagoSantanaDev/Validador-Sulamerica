import 'consulta_guia.dart';

/// Item de consulta enviado ao backend em lote (/api/consultas).
class ConsultaLoteItem {
  const ConsultaLoteItem({required this.tipo, required this.chave});

  final TipoConsultaGuia tipo;
  final String chave;
}

class ResultadoConsultaLote {
  const ResultadoConsultaLote({
    required this.chave,
    required this.tipo,
    required this.sucesso,
    this.elegivel,
    this.rotuloElegibilidade,
    this.statusSenha,
    this.erro,
  });

  factory ResultadoConsultaLote.fromJson(Map<String, dynamic> json) {
    final String tipo = json['tipo'] as String? ?? '';
    return ResultadoConsultaLote(
      chave: json['chave'] as String? ?? '',
      tipo: tipo == 'senha'
          ? TipoConsultaGuia.senha
          : TipoConsultaGuia.elegibilidade,
      sucesso: json['sucesso'] as bool? ?? false,
      elegivel: json['elegivel'] as bool?,
      rotuloElegibilidade: json['rotuloElegibilidade'] as String?,
      statusSenha: json['statusSenha'] as String?,
      erro: json['erro'] as String?,
    );
  }

  final String chave;
  final TipoConsultaGuia tipo;
  final bool sucesso;
  final bool? elegivel;
  final String? rotuloElegibilidade;
  final String? statusSenha;
  final String? erro;
}
