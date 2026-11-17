import 'consulta_lote.dart';

/// Lote aceito pelo backend (`POST /api/lotes`).
class LoteRemoto {
  const LoteRemoto({
    required this.id,
    required this.estado,
    required this.total,
    this.location,
  });

  final String id;
  final String estado;
  final int total;

  /// Valor do header `Location` (rota SSE do lote).
  final String? location;

  static LoteRemoto fromJson(Map<String, dynamic> json, {String? location}) {
    return LoteRemoto(
      id: json['id'] as String? ?? '',
      estado: json['estado'] as String? ?? 'na_fila',
      total: (json['total'] as num?)?.toInt() ?? 0,
      location: location,
    );
  }
}

/// Evento `progresso` de um lote em execução.
class ProgressoLote {
  const ProgressoLote({required this.concluidas, required this.total});

  final int concluidas;
  final int total;

  double get fracao => total <= 0 ? 0 : concluidas / total;

  static ProgressoLote fromJson(Map<String, dynamic> json) {
    return ProgressoLote(
      concluidas: (json['concluidas'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Evento `resultado` de um lote concluído.
class ResultadoLoteEvento {
  const ResultadoLoteEvento({required this.status, required this.resultados});

  final String status;
  final List<ResultadoConsultaLote> resultados;

  static ResultadoLoteEvento fromJson(Map<String, dynamic> json) {
    final Object? itens = json['resultados'];
    return ResultadoLoteEvento(
      status: json['status'] as String? ?? '',
      resultados: itens is List
          ? [
              for (final Object? item in itens)
                if (item is Map)
                  ResultadoConsultaLote.fromJson(item.cast<String, dynamic>()),
            ]
          : const [],
    );
  }
}
