import 'package:xml/xml.dart';

import '../models/guia_tiss.dart';
import '../models/lote_guias_extraido.dart';
import '../models/procedimento.dart';
import '../models/profissional_solicitante.dart';
import '../models/informacoes_lote.dart';
import 'xml_lote_guias_exceptions.dart';

class XmlLoteGuiasDatasource {
  const XmlLoteGuiasDatasource();

  List<GuiaTiss> extrairGuias(String conteudoXml) {
    return extrairLote(conteudoXml).guias;
  }

  LoteGuiasExtraido extrairLote(String conteudoXml) {
    final XmlDocument documento = _parsear(conteudoXml);
    final List<XmlElement> elementosGuia = _elementosGuia(documento);

    if (elementosGuia.isEmpty) {
      throw const NenhumaGuiaEncontradaException(
        'Nenhuma guia guiaSP-SADT foi encontrada no lote.',
      );
    }
    return LoteGuiasExtraido(
      informacoes: _extrairInformacoes(documento, elementosGuia),
      guias: elementosGuia.map(_converterParaGuiaTiss).toList(),
    );
  }

  InformacoesLote extrairInformacoesDoLote(String conteudoXml) {
    final XmlDocument documento = _parsear(conteudoXml);
    return _extrairInformacoes(documento, _elementosGuia(documento));
  }

  List<XmlElement> _elementosGuia(XmlDocument documento) =>
      documento.findAllElements('guiaSP-SADT', namespace: '*').toList();

  InformacoesLote _extrairInformacoes(
    XmlDocument documento,
    List<XmlElement> guias,
  ) {
    return InformacoesLote(
      versao: _textoPrimeiro(documento, const ['Padrao']) ??
          _textoPrimeiro(documento, const ['versaoPadrao']),
      tipoTransacao: _textoPrimeiro(
        documento,
        const ['identificacaoTransacao', 'tipoTransacao'],
      ),
      prestadorCnpjCpf: _textoPrimeiro(
            documento,
            const ['identificacaoPrestador', 'CNPJ'],
          ) ??
          _textoPrimeiro(
            documento,
            const ['identificacaoPrestador', 'CPF'],
          ) ??
          _textoPrimeiro(
            documento,
            const ['identificacaoPrestador', 'codigoPrestadorNaOperadora'],
          ) ??
          _textoPrimeiro(documento, const ['origem', 'CNPJ']) ??
          _textoPrimeiro(documento, const ['origem', 'CPF']) ??
          _textoPrimeiro(
            documento,
            const ['origem', 'codigoPrestadorNaOperadora'],
          ),
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
  }

  String? _somarValorTotalGeral(XmlDocument documento) {
    final List<XmlElement> totais =
        documento.findAllElements('valorTotalGeral', namespace: '*').toList();
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
      numeroCarteira: _textoLiteralDoFilhoAninhado(
        guiaElement,
        const ['dadosBeneficiario', 'numeroCarteira'],
      ),
      senha: _textoLiteralDeElementoDescendente(guiaElement, 'senha'),
      dataAutorizacao: _textoDoFilhoAninhado(
        guiaElement,
        const ['dadosAutorizacao', 'dataAutorizacao'],
      ),
      nomeBeneficiario: _textoDoFilhoAninhado(
            guiaElement,
            const ['dadosBeneficiario', 'nomeBeneficiario'],
          ) ??
          _textoDeElementoDescendente(guiaElement, 'nomeBeneficiario'),
      solicitante: _extrairSolicitante(guiaElement),
      procedimentos: _extrairProcedimentos(guiaElement),
    );
  }

  ProfissionalSolicitante? _extrairSolicitante(XmlElement guiaElement) {
    final String? numeroConselho = _textoLiteralDoFilhoAninhado(
      guiaElement,
      const [
        'dadosSolicitante',
        'profissionalSolicitante',
        'numeroConselhoProfissional',
      ],
    );
    if (numeroConselho == null) return null;
    return ProfissionalSolicitante(numeroConselho: numeroConselho);
  }

  List<Procedimento> _extrairProcedimentos(XmlElement guiaElement) {
    final List<XmlElement> elementos = guiaElement
        .findAllElements('procedimentoExecutado', namespace: '*')
        .toList();

    final List<Procedimento> resultado = [];
    for (final XmlElement elemento in elementos) {
      final String? codigo = _textoDoFilhoAninhado(
        elemento,
        const ['procedimento', 'codigoProcedimento'],
      );
      if (codigo == null || codigo.isEmpty) continue;

      final String? quantidadeTexto =
          _textoDoFilhoAninhado(elemento, const ['quantidadeExecutada']);
      final int quantidade = int.tryParse(quantidadeTexto ?? '') ?? 1;
      final String? codigoTabela = _textoDoFilhoAninhado(
        elemento,
        const ['procedimento', 'codigoTabela'],
      );

      resultado.add(
        Procedimento(
          codigo: codigo,
          quantidade: quantidade,
          codigoTabela: codigoTabela,
          dataExecucao:
              _textoDoFilhoAninhado(elemento, const ['dataExecucao']),
        ),
      );
    }

    return resultado;
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

  String? _textoLiteralDoFilhoAninhado(
    XmlElement raiz,
    List<String> caminho,
  ) {
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
    final String texto = atual.innerText;
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

  String? _textoLiteralDeElementoDescendente(
    XmlElement raiz,
    String nomeLocal,
  ) {
    for (final XmlElement elemento
        in raiz.findAllElements(nomeLocal, namespace: '*')) {
      final String texto = elemento.innerText;
      if (texto.isNotEmpty) return texto;
    }
    return null;
  }
}
