import '../datasources/xml_lote_guias_datasource.dart';
import '../models/erro_validacao.dart';
import '../models/guia_tiss.dart';
import '../models/guia_validada.dart';
import 'regras/regra_codigo_bilateral.dart';
import 'regras/regra_senha_prefixo.dart';
import 'regras/regra_validacao.dart';
import 'validador_guias_repository.dart';

class ValidadorGuiasRepositoryImpl implements ValidadorGuiasRepository {
  ValidadorGuiasRepositoryImpl({
    XmlLoteGuiasDatasource? datasource,
    List<RegraValidacao>? regras,
  })  : _datasource = datasource ?? const XmlLoteGuiasDatasource(),
        _regras = regras ??
            const [
              RegraSenhaPrefixo(),
              RegraCodigoBilateral(),
            ];

  final XmlLoteGuiasDatasource _datasource;
  final List<RegraValidacao> _regras;

  @override
  List<GuiaValidada> validarLote(String conteudoXml) {
    final List<GuiaTiss> guias = _datasource.extrairGuias(conteudoXml);
    return guias.map(_aplicarRegras).toList();
  }

  GuiaValidada _aplicarRegras(GuiaTiss guia) {
    final List<ErroValidacao> erros = _regras
        .map((regra) => regra.validar(guia))
        .whereType<ErroValidacao>()
        .toList();
    return GuiaValidada(guia: guia, erros: erros);
  }
}
