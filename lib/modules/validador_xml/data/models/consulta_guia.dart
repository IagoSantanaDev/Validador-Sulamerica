/// Resultado de uma consulta ao portal SulAmérica feita por guia durante a
/// validação (elegibilidade ou autorização VPP).
enum TipoConsultaGuia { elegibilidade, autorizacaoVpp }

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