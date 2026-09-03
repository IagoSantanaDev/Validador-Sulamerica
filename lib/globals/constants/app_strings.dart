/// Strings estáticas da UI centralizadas, facilitando manutenção e futura
/// internacionalização.
class AppStrings {
  const AppStrings._();

  static const String tituloApp = 'Validador de Guias TISS';
  static const String tituloPagina =
      'Validação online de arquivos XML no padrão TISS da ANS.';
  static const String subtituloPagina =
      'Pré-validação de guias TISS (guiaSP-SADT) antes do envio à SulAmérica';

  // Drop zone
  static const String dropZoneTituloArrastar =
      'Clique aqui para selecionar o arquivo';
  static const String dropZoneAcaoSelecionar =
      'ou arraste-o para cá para iniciar a validação';
  static const String dropZoneArquivoSelecionado = 'Arquivo selecionado';
  static const String botaoTrocarArquivo = 'Trocar arquivo';
  static const String botaoSelecionarArquivo = 'Selecionar arquivo';
  static const String extensaoAceita = 'Somente arquivos .xml';
  static const String mensagemArquivoInvalidoExtensao =
      'Selecione um arquivo com extensão .xml';

  // Ações e estados
  static const String botaoValidar = 'Validar arquivo';
  static const String mensagemValidando = 'Validando guias...';

  // Resultado da validação
  static const String resultadoTitulo = 'Resultado da Validação';
  static const String rotuloNomeArquivo = 'Nome';
  static const String rotuloTamanhoArquivo = 'Tamanho';
  static const String rotuloTipoGuia = 'Tipo de guia';
  static const String rotuloQtdGuias = 'Qtd. guias';
  static const String rotuloComErro = 'Com erro';
  static const String valorTipoGuia = 'SP/SADT';

  // Estados de conclusão / falha
  static const String semErrosTitulo = 'Nenhum erro encontrado';
  static const String semErrosDetalhe =
      'Todas as guias do lote passaram nas regras de validação.';
  static const String falhaValidacaoTitulo = 'Não foi possível validar';

  // Campos exibidos por guia
  static const String rotuloNumeroGuia = 'Guia';
  static const String rotuloNumeroCarteira = 'Carteira';
  static const String statusValido = 'Válida';
  static const String statusErro = 'Com erro';
}