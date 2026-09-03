import '../../models/erro_validacao.dart';
import '../../models/guia_tiss.dart';
import 'regra_validacao.dart';

/// numeroCarteira é obrigatório e deve sempre começar com o dígito 5.
class RegraNumeroCarteiraPrefixo extends RegraValidacao {
  const RegraNumeroCarteiraPrefixo();

  static const String _prefixoObrigatorio = '5';

  @override
  ErroValidacao? validar(GuiaTiss guia) {
    final String? numeroCarteira = guia.numeroCarteira;

    if (numeroCarteira == null || numeroCarteira.isEmpty) {
      return const ErroValidacao(
        campo: 'numeroCarteira',
        mensagem: 'numeroCarteira não informado',
      );
    }

    if (!numeroCarteira.startsWith(_prefixoObrigatorio)) {
      return const ErroValidacao(
        campo: 'numeroCarteira',
        mensagem: 'numeroCarteira deve começar com 5',
      );
    }

    return null;
  }
}
