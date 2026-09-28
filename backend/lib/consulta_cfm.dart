/// Boundary for CFM lookups, independent of the unconfirmed wire contract.
abstract interface class ConsultaCfm {
  Future<ResultadoConsultaCfm> consultar({
    required String crm,
    required String uf,
  });
}

enum EstadoConsultaCfm {
  conformeDados,
  naoEncontrado,
  naoVerificado,
  falhaConsulta,
}

/// Data returned by a CFM lookup after its response has been interpreted.
final class ResultadoConsultaCfm {
  const ResultadoConsultaCfm({
    required this.estado,
    this.crm,
    this.uf,
    this.nome,
    this.situacao,
    this.tipoInscricao,
    this.dataAtualizacao,
    this.especialidade,
  });

  final EstadoConsultaCfm estado;
  final String? crm;
  final String? uf;
  final String? nome;
  final String? situacao;
  final String? tipoInscricao;
  final String? dataAtualizacao;
  final String? especialidade;
}
