import 'package:validador_backend/modules/sulamerica/data/motivo_bloqueio_portal.dart';

enum CategoriaFalhaConsultaPortal {
  sessao,
  transporte,
  http,
  respostaInesperada,
  cancelada,
}

class ResultadoConsultaPortal<T> {
  const ResultadoConsultaPortal.sucesso({
    required this.dados,
    required this.status,
  })  : sucesso = true,
        categoria = null,
        retryable = false,
        falhaElegivelCircuito = false,
        motivoBloqueio = null,
        retryAfter = null;

  const ResultadoConsultaPortal.falha({
    required this.categoria,
    required this.status,
    this.retryable = false,
    this.falhaElegivelCircuito = false,
    this.motivoBloqueio,
    this.retryAfter,
  })  : sucesso = false,
        dados = null;

  final bool sucesso;
  final T? dados;
  final int? status;
  final CategoriaFalhaConsultaPortal? categoria;
  final bool retryable;
  final bool falhaElegivelCircuito;
  final MotivoBloqueioPortal? motivoBloqueio;
  final Duration? retryAfter;
}

bool ehFalhaDeSessaoPortal(int? status) => status == 401 || status == 403;
