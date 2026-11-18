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
        categoria = null;

  const ResultadoConsultaPortal.falha({
    required this.categoria,
    required this.status,
  })  : sucesso = false,
        dados = null;

  final bool sucesso;
  final T? dados;
  final int? status;
  final CategoriaFalhaConsultaPortal? categoria;
}

bool ehFalhaDeSessaoPortal(int? status) => status == 401 || status == 403;
