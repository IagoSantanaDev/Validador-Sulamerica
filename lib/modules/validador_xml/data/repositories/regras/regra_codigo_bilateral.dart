import '../../models/erro_validacao.dart';
import '../../models/guia_tiss.dart';
import 'regra_validacao.dart';

class RegraCodigoBilateral extends RegraValidacao {
  const RegraCodigoBilateral();

  static const Set<String> codigosBilaterais = {
    '40103269',
    '40103609',
    '40201058',
    '40708063',
    '40801047',
    '40801055',
    '40801110',
    '40808033',
    '40808041',
    '40901025',
    '40901360',
    '40901378',
    '41101073',
    '41101081',
    '41101103',
    '41101480',
    '40901114',
  };

  @override
  ErroValidacao? validar(GuiaTiss guia) {
    for (final procedimento in guia.procedimentos) {
      if (codigosBilaterais.contains(procedimento.codigo) &&
          procedimento.quantidade > 1) {
        return ErroValidacao(
          campo: 'procedimentos',
          mensagem: 'Código Bilateral (${procedimento.codigo})',
        );
      }
    }
    return null;
  }
}
