class InformacoesLote {
  const InformacoesLote({
    this.versao,
    this.tipoTransacao,
    this.hash,
    this.prestadorCnpjCpf,
    this.operadoraRegistroANS,
    this.numeroLote,
    this.qtdGuias,
    this.valorTotalInformado,
  });

  final String? versao;
  final String? tipoTransacao;
  final String? hash;
  final String? prestadorCnpjCpf;
  final String? operadoraRegistroANS;
  final String? numeroLote;
  final int? qtdGuias;
  final String? valorTotalInformado;

  static const InformacoesLote vazio = InformacoesLote();
}