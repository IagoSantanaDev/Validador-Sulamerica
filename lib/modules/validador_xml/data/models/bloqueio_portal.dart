class BloqueioPortal {
  const BloqueioPortal({
    required this.motivo,
    required this.codigo,
    required this.mensagem,
    required this.segundosRestantes,
  });

  final String motivo;
  final String codigo;
  final String mensagem;
  final int segundosRestantes;

  factory BloqueioPortal.fromJson(Map<String, dynamic> json) {
    final dynamic segundos = json['retryAfterSegundos'];
    return BloqueioPortal(
      motivo: json['motivo'] is String
          ? json['motivo'] as String
          : 'portal_indisponivel',
      codigo: json['codigo'] is String ? json['codigo'] as String : 'PORTAL',
      mensagem: json['mensagem'] is String
          ? json['mensagem'] as String
          : 'Consultas temporariamente bloqueadas.',
      segundosRestantes: segundos is int && segundos > 0 ? segundos : 0,
    );
  }

  BloqueioPortal comSegundosRestantes(int segundos) => BloqueioPortal(
    motivo: motivo,
    codigo: codigo,
    mensagem: mensagem,
    segundosRestantes: segundos < 0 ? 0 : segundos,
  );
}
