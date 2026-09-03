/// Dados brutos extraídos de uma ocorrência de <guiaSP-SADT> no XML.
///
/// Representa exatamente um bloco do lote, sem deduplicar — o mesmo
/// numeroGuiaPrestador pode se repetir em mais de um bloco.
class GuiaTiss {
  const GuiaTiss({
    required this.numeroGuiaPrestador,
    required this.numeroCarteira,
    required this.senha,
  });

  final String numeroGuiaPrestador;
  final String? numeroCarteira;
  final String? senha;
}
