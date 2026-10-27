import 'package:freezed_annotation/freezed_annotation.dart';

part 'informacoes_lote.freezed.dart';

@freezed
abstract class InformacoesLote with _$InformacoesLote {
  const factory InformacoesLote({
    String? versao,
    String? tipoTransacao,
    String? hash,
    String? prestadorCnpjCpf,
    String? operadoraRegistroANS,
    String? numeroLote,
    int? qtdGuias,
    String? valorTotalInformado,
  }) = _InformacoesLote;

  static const InformacoesLote vazio = InformacoesLote();
}
