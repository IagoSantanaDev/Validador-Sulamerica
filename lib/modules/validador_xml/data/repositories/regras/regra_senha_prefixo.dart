import '../../models/erro_validacao.dart';
import '../../models/guia_tiss.dart';
import 'regra_validacao.dart';

class RegraSenhaPrefixo extends RegraValidacao {
  const RegraSenhaPrefixo();

  static const String _prefixoObrigatorio = '5';
  static const int _tamanhoMaximo = 10;

  @override
  ErroValidacao? validar(GuiaTiss guia) {
    final String? senha = guia.senha;
    if (senha == null || senha.isEmpty) {
      return const ErroValidacao(
        campo: 'senha',
        mensagem: 'senha não informada',
      );
    }
    if (!senha.startsWith(_prefixoObrigatorio)) {
      return const ErroValidacao(
        campo: 'senha',
        mensagem: 'senha deve começar com 5',
      );
    }
    if (senha.length > _tamanhoMaximo) {
      return const ErroValidacao(
        campo: 'senha',
        mensagem: 'senha deve ter no máximo 10 caracteres',
      );
    }
    return null;
  }
}