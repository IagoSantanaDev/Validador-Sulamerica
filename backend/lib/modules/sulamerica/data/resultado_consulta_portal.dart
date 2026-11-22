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
        falhaElegivelCircuito = false;

  const ResultadoConsultaPortal.falha({
    required this.categoria,
    required this.status,
    this.retryable = false,
    this.falhaElegivelCircuito = false,
  })  : sucesso = false,
        dados = null;

  final bool sucesso;
  final T? dados;
  final int? status;
  final CategoriaFalhaConsultaPortal? categoria;
  final bool retryable;
  final bool falhaElegivelCircuito;
}

bool ehFalhaDeSessaoPortal(int? status) => status == 401 || status == 403;
