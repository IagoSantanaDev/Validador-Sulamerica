/// Representa um erro de validação encontrado em uma guia.
class ErroValidacao {
  const ErroValidacao({
    required this.campo,
    required this.mensagem,
  });

  final String campo;
  final String mensagem;
}
