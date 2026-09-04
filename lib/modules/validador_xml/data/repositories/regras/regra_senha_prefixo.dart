import '../../models/erro_validacao.dart';
import '../../models/guia_tiss.dart';
import 'regra_validacao.dart';

class RegraSenhaPrefixo extends RegraValidacao {
  const RegraSenhaPrefixo();

  /// Regra única da senha VPP exibida ao cliente: começa com 5 e tem
  /// exatamente 10 dígitos (fonte para o front validar antes da API).
  static const String prefixoObrigatorio = '5';
  static const int tamanhoExato = 10;

  @override
  ErroValidacao? validar(GuiaTiss guia) {
    final String? senha = guia.senha;
    if (senha == null || senha.isEmpty) {
      return const ErroValidacao(
        campo: 'senha',
        mensagem: 'Senha não informada',
      );
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
    return null;
  }
}