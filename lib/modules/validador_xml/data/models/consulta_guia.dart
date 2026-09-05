enum TipoConsultaGuia { elegibilidade, senha }

class ConsultaGuia {
  const ConsultaGuia({
    required this.sucesso,
    required this.descricao,
    this.tipo = TipoConsultaGuia.elegibilidade,
  });

  final TipoConsultaGuia tipo;
  final bool sucesso;
  final String descricao;
}