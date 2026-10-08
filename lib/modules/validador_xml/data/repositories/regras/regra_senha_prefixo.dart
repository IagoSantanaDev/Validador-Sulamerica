import '../../models/erro_validacao.dart';
import '../../models/guia_tiss.dart';
import 'regra_validacao.dart';

class RegraSenhaPrefixo extends RegraValidacao {
  const RegraSenhaPrefixo();

  static const String prefixoObrigatorio = '5';
  static const int tamanhoExato = 10;

  static bool senhaValida(String senha) =>
      senha.length == tamanhoExato &&
      senha.startsWith(prefixoObrigatorio) &&
      senha.codeUnits
          .skip(1)
          .every((unidade) => unidade >= 48 && unidade <= 57);

  @override
  ErroValidacao? validar(GuiaTiss guia) {
    final String? senha = guia.senha;
    if (senha == null || senha.isEmpty) {
      return null;
    }
    if (!senha.startsWith(prefixoObrigatorio)) {
      return const ErroValidacao(
        campo: 'senha',
        mensagem: 'senha deve começar com 5',
      );
    }
    if (senha.length != tamanhoExato) {
      return const ErroValidacao(
        campo: 'senha',
        mensagem: 'senha deve ter exatamente 10 caracteres',
      );
    }
    if (!senhaValida(senha)) {
      return const ErroValidacao(
        campo: 'senha',
        mensagem: 'senha deve conter apenas dígitos ASCII',
      );
    }
    return null;
  }
}
