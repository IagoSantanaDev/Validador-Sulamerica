import '../datasources/xml_lote_guias_datasource.dart';
import '../models/erro_validacao.dart';
import '../models/guia_tiss.dart';
import '../models/guia_validada.dart';
import '../services/classificador_tuss_local.dart';
import 'regras/regra_codigo_bilateral.dart';
import 'regras/regra_crm_tamanho.dart';
import 'regras/regra_data_autorizacao.dart';
import 'regras/regra_senha_prefixo.dart';
import 'regras/regra_senha_procedimento.dart';
import 'regras/regra_tuss.dart';
import 'regras/regra_validacao.dart';
import 'validador_guias_repository.dart';

class ValidadorGuiasRepositoryImpl implements ValidadorGuiasRepository {
  ValidadorGuiasRepositoryImpl({
    XmlLoteGuiasDatasource? datasource,
    List<RegraValidacao>? regras,
    ClassificadorTussLocal? classificadorTuss,
  })  : _datasource = datasource ?? const XmlLoteGuiasDatasource(),
        _classificadorTuss = classificadorTuss,
        _regras = regras ??
            [
              const RegraCrmTamanho(),
              const RegraSenhaProcedimento(),
              const RegraSenhaPrefixo(),
              const RegraDataAutorizacao(),
              const RegraCodigoBilateral(),
              if (classificadorTuss != null) RegraTuss(classificadorTuss),
            ];

  final XmlLoteGuiasDatasource _datasource;
  final ClassificadorTussLocal? _classificadorTuss;
  final List<RegraValidacao> _regras;

  @override
  Future<void> preparar() async {
    await _classificadorTuss?.preparar();
  }

  @override
  List<GuiaValidada> validarLote(String conteudoXml) {
    return validarGuias(_datasource.extrairGuias(conteudoXml));
  }

  @override
  List<GuiaValidada> validarGuias(List<GuiaTiss> guias) {
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
