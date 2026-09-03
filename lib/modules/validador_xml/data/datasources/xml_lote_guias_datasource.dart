import 'package:xml/xml.dart';

import '../models/guia_tiss.dart';
import 'xml_lote_guias_exceptions.dart';

/// Isola a leitura e o parsing do XML de lote de guias TISS.
/// Nenhuma regra de negócio deve viver aqui — apenas extração de dados.
class XmlLoteGuiasDatasource {
  const XmlLoteGuiasDatasource();

  static const String _tagGuiaSpSadt = 'guiaSP-SADT';
  static const String _tagCabecalhoGuia = 'cabecalhoGuia';
  static const String _tagNumeroGuiaPrestador = 'numeroGuiaPrestador';
  static const String _tagDadosBeneficiario = 'dadosBeneficiario';
  static const String _tagNumeroCarteira = 'numeroCarteira';
  static const String _tagSenha = 'senha';

  /// Extrai todas as ocorrências de guiaSP-SADT do conteúdo XML informado,
  /// na ordem original do documento.
  ///
  /// namespace: '*' é usado porque o TISS sempre qualifica as tags com o
  /// prefixo ans:, e queremos casar pelo nome local independente disso.
  List<GuiaTiss> extrairGuias(String conteudoXml) {
    final XmlDocument documento = _parsear(conteudoXml);

    final List<XmlElement> elementosGuia = documento
        .findAllElements(_tagGuiaSpSadt, namespace: '*')
        .toList();

    if (elementosGuia.isEmpty) {
      throw const NenhumaGuiaEncontradaException(
        'Nenhuma guia guiaSP-SADT foi encontrada no lote.',
      );
    }

    return elementosGuia.map(_converterParaGuiaTiss).toList();
  }

  XmlDocument _parsear(String conteudoXml) {
    try {
      return XmlDocument.parse(conteudoXml);
    } on XmlException catch (erro) {
      throw XmlMalFormadoException(
        'Não foi possível ler o XML. Verifique se o arquivo está bem '
        'formado. Detalhe: ${erro.message}',
      );
    }
  }

  GuiaTiss _converterParaGuiaTiss(XmlElement guiaElement) {
    final String numeroGuia = _textoDoFilhoAninhado(
          guiaElement,
          const [_tagCabecalhoGuia, _tagNumeroGuiaPrestador],
        ) ??
        '';

    final String? numeroCarteira = _textoDoFilhoAninhado(
      guiaElement,
      const [_tagDadosBeneficiario, _tagNumeroCarteira],
    );
    final String? senha = _textoDeElementoDescendente(guiaElement, _tagSenha);

    return GuiaTiss(
      numeroGuiaPrestador: numeroGuia,
      numeroCarteira: numeroCarteira,
      senha: senha,
    );
  }

  /// Navega por uma cadeia de tags filhas diretas (por nome local) e
  /// retorna o texto do último elemento encontrado, ou null se algum
  /// nível do caminho não existir.
  String? _textoDoFilhoAninhado(XmlElement raiz, List<String> caminho) {
    XmlElement atual = raiz;

    for (final String tag in caminho) {
      XmlElement? proximo;
      for (final XmlElement filho in atual.childElements) {
        if (filho.name.local == tag) {
          proximo = filho;
          break;
        }
      }
      if (proximo == null) return null;
      atual = proximo;
    }

    final String texto = atual.innerText.trim();
    return texto.isEmpty ? null : texto;
  }

  String? _textoDeElementoDescendente(XmlElement raiz, String nomeLocal) {
    for (final XmlElement elemento
        in raiz.findAllElements(nomeLocal, namespace: '*')) {
      final String texto = elemento.innerText.trim();
      if (texto.isNotEmpty) return texto;
    }
    return null;
  }
}
