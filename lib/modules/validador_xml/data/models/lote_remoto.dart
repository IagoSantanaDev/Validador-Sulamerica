import 'consulta_lote.dart';
import 'consulta_guia.dart';

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
  const ResultadoLoteEvento({
    required this.status,
    required this.resultados,
    this.pendentes = const [],
  });

  final String status;
  final List<ResultadoConsultaLote> resultados;
  final List<PendenciaConsultaLote> pendentes;

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
      pendentes: json['pendentes'] is List
          ? [
              for (final Object? item in json['pendentes'] as List)
                if (item is Map)
                  if (PendenciaConsultaLote.fromJson(
                        item.cast<String, dynamic>(),
                      )
                      case final PendenciaConsultaLote pendencia)
                    pendencia,
            ]
          : const [],
    );
  }
}

class PendenciaConsultaLote {
  const PendenciaConsultaLote({
    required this.tipo,
    required this.chave,
    required this.motivo,
  });

  final TipoConsultaGuia tipo;
  final String chave;
  final String motivo;

  static PendenciaConsultaLote? fromJson(Map<String, dynamic> json) {
    final String? tipo = json['tipo'] as String?;
    final String? chave = json['chave'] as String?;
    final String? motivo = json['motivo'] as String?;
    if (chave == null || motivo == null) return null;
    final TipoConsultaGuia? tipoConsulta = switch (tipo) {
      'elegibilidade' => TipoConsultaGuia.elegibilidade,
      'senha' => TipoConsultaGuia.senha,
      _ => null,
    };
    if (tipoConsulta == null) return null;
    return PendenciaConsultaLote(
      tipo: tipoConsulta,
      chave: chave,
      motivo: motivo,
    );
  }
}
