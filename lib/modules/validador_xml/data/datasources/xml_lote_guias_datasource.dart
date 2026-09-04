import 'package:xml/xml.dart';

import '../models/guia_tiss.dart';
import '../models/informacoes_lote.dart';
import 'xml_lote_guias_exceptions.dart';

/// Parsing do XML de lote de guias TISS (apenas extração, sem regra de
/// negócio). `namespace: '*'` casa tags qualificadas com o prefixo ans:.
class XmlLoteGuiasDatasource {
  const XmlLoteGuiasDatasource();

  List<GuiaTiss> extrairGuias(String conteudoXml) {
    final XmlDocument documento = _parsear(conteudoXml);
    final List<XmlElement> elementosGuia = documento
        .findAllElements('guiaSP-SADT', namespace: '*')
        .toList();

    if (elementosGuia.isEmpty) {
      throw const NenhumaGuiaEncontradaException(
        'Nenhuma guia guiaSP-SADT foi encontrada no lote.',
      );
    }
    return elementosGuia.map(_converterParaGuiaTiss).toList();
  }

  InformacoesLote extrairInformacoesDoLote(String conteudoXml) {
    try {
      final XmlDocument documento = _parsear(conteudoXml);
      final List<XmlElement> guias = documento
          .findAllElements('guiaSP-SADT', namespace: '*')
          .toList();

      return InformacoesLote(
        versao: _textoPrimeiro(documento, const ['Padrao']) ??
            _textoPrimeiro(documento, const ['versaoPadrao']),
        tipoTransacao: _textoPrimeiro(
          documento,
          const ['identificacaoTransacao', 'tipoTransacao'],
        ),
        prestadorCnpjCpf:
            _textoPrimeiro(documento, const ['identificacaoPrestador', 'CNPJ']) ??
                _textoPrimeiro(
                  documento,
                  const ['identificacaoPrestador', 'CPF'],
                ) ??
                _textoPrimeiro(documento, const ['origem', 'CNPJ']) ??
                _textoPrimeiro(documento, const ['origem', 'CPF']),
        operadoraRegistroANS:
            _textoPrimeiro(documento, const ['destino', 'registroANS']),
        numeroLote: _textoPrimeiro(documento, const ['numeroLote']),
        qtdGuias: guias.isEmpty ? null : guias.length,
        valorTotalInformado: _somarValorTotalGeral(documento) ??
            (guias.isEmpty
                ? null
                : _textoDoFilhoAninhado(
                    guias.first,
                    const ['valorTotalGuia'],
                  )),
      );
    } catch (_) {
      return InformacoesLote.vazio;
    }
  }

  /// Soma todos os `<ans:valorTotalGeral>` do lote. Retorna null quando não
  /// há nenhum valor numérico válido.
  String? _somarValorTotalGeral(XmlDocument documento) {
    final List<XmlElement> totais = documento
        .findAllElements('valorTotalGeral', namespace: '*')
        .toList();
    if (totais.isEmpty) return null;

    double soma = 0;
    var algumValido = false;
    for (final XmlElement total in totais) {
      final double? valor = double.tryParse(total.innerText.trim());
      if (valor != null) {
        soma += valor;
        algumValido = true;
      }
    }
    if (!algumValido) return null;
    return soma.toStringAsFixed(2);
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
          const ['cabecalhoGuia', 'numeroGuiaPrestador'],
        ) ??
        '';

    return GuiaTiss(
      numeroGuiaPrestador: numeroGuia,
      numeroCarteira: _textoDoFilhoAninhado(
        guiaElement,
        const ['dadosBeneficiario', 'numeroCarteira'],
      ),
      senha: _textoDeElementoDescendente(guiaElement, 'senha'),
      nomeBeneficiario: _textoDoFilhoAninhado(
            guiaElement,
            const ['dadosBeneficiario', 'nomeBeneficiario'],
          ) ??
          _textoDeElementoDescendente(guiaElement, 'nomeBeneficiario'),
    );
  }

  String? _textoPrimeiro(XmlDocument documento, List<String> caminho) {
    for (final XmlElement raiz
        in documento.findAllElements(caminho.first, namespace: '*')) {
      final String? valor = _textoDoFilhoAninhado(raiz, caminho.sublist(1));
      if (valor != null && valor.isNotEmpty) return valor;
    }
    return null;
  }

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