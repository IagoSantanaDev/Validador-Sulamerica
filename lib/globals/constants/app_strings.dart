class AppStrings {
  const AppStrings._();

  static const String tituloApp = 'Validador SulAmerica';
  static const String valorIndisponivel = '—';
  static const String mensagemArquivoInvalidoExtensao =
      'Selecione um arquivo com extensão .xml';
  static const String mensagemFalhaCarregamentoArquivo =
      'Não foi possível carregar o arquivo. Tente novamente.';

  static const String jumbotronLegenda =
      'Validação online de arquivos XML no padrão TISS da ANS.';
  static const String dropZoneTexto =
      'Clique aqui para selecionar o arquivo ou arraste ele para cá para iniciar a validação.';
  static const String lendoValidandoXml = 'Lendo e validando XML...';
  static const String consultandoSulAmerica = 'Consultando SulAmérica...';

  static const String resultadoTitulo = 'Resultado da Validação';
  static const String protocoloRotulo = 'Protocolo nº';
  static const String processadoEmPrefix = 'Processado em ';
  static const String processadoEmSufix = ' segundos';
  static const String validarOutroArquivo = 'Validar outro arquivo';
  static const String validacoesPorGuia = 'Validações por guia';
  static const String consultasPendentesTitulo =
      'Consultas ao portal pendentes';
  static const String avisoConsultaBackendTitulo =
      'Aviso na consulta ao portal';
  static const String consultasPendentesMensagem =
      'Algumas consultas ao portal não puderam ser concluídas após as '
      'tentativas automáticas. '
      'Elas não foram classificadas como erros do XML.';
  static const String consultasPendentesEmAndamento =
      'Tentando consultar os itens pendentes...';
  static const String consultasAguardandoRetentativa =
      'Aguardando nova tentativa automática para consultas sem resposta...';
  static const String consultasPrazoExpirado =
      'O lote atingiu o limite de cinco minutos. Os itens pendentes não foram '
      'consultados e podem ser tentados manualmente.';
  static const String filaConsultaBackendCheia =
      'A fila de consultas está ocupada. Aguarde um momento e tente novamente.';
  static const String servicoConsultaIndisponivel =
      'O serviço de consultas está temporariamente indisponível. Tente novamente em instantes.';
  static const String erroConexaoConsultaBackend =
      'Não foi possível conectar ao serviço de consultas. Verifique sua conexão e tente novamente.';
  static const String erroConsultaBackendExpirada =
      'A consulta ao portal está demorando mais que o esperado. Tente novamente.';
  static const String erroSessaoConsultaBackend =
      'Não foi possível validar a sessão de consulta. Tente novamente.';
  static const String erroConsultaBackendGenerico =
      'Não foi possível concluir as consultas ao portal agora. Tente novamente mais tarde.';

  static const String metadadoNome = 'Nome';
  static const String metadadoTamanho = 'Tamanho';
  static const String metadadoVersao = 'Versão';
  static const String metadadoTipoTransacao = 'Tipo de Transação';
  static const String metadadoHash = 'Hash';
  static const String metadadoPrestador = 'Prestador';
  static const String metadadoOperadora = 'Operadora';
  static const String metadadoNumeroLote = 'Nº do Lote';
  static const String metadadoQtdGuias = 'Qtd Guias';
  static const String metadadoValorTotalInformado = 'Valor Total Informado';

  static const String semErrosTitulo = 'Nenhum erro encontrado';
  static const String semErrosDetalhe =
      'Todas as guias do lote passaram nas regras de validação.';
  static const String falhaValidacaoTitulo = 'Não foi possível validar';

  static const String rotuloGuia = 'Guia';
  static const String rotuloDetalhes = 'Detalhes';
  static const String rotuloCarteira = 'Carteira';
  static const String rotuloSenha = 'Senha';
  static const String rotuloDataAutorizacao = 'Data de autorização';
  static const String rotuloBeneficiario = 'Beneficiário';
  static const String rotuloElegibilidade = 'Elegibilidade';
  static const String dialogoFechar = 'Fechar';

  static const String apiVerificandoTitulo = 'Conectando à API';
  static const String apiVerificandoMensagem =
      'Verificando conexão com o servidor intermediário...';
  static const String apiIndisponivelTitulo = 'API indisponível';
  static const String apiIndisponivelMensagem =
      'Não foi possível conectar ao servidor intermediário.';
  static const String apiIndisponivelDetalhe =
      'Confira se a variável API_URL está configurada no build '
      '(ex.: API_URL=https://seu-backend.onrender.com).';
  static const String apiTentarNovamente = 'Tentar novamente';

  static const String erroCarteiraInvalida = 'Número da carteira inválido';
  static const String erroNaoElegivel = 'Beneficiário não elegível';
  static const String erroCarteiraNaoEncontrada =
      'Carteira não encontrada no portal';
  static const String erroSenhaInvalida = 'Senha inválida';
  static const String erroSenhaNaoEncontrada = 'Senha não encontrada no portal';
  static const String erroLoginFalhou =
      'Não foi possível iniciar a consulta ao portal. Verifique os dados do prestador e tente novamente.';
  static const String erroCredenciaisAusentes =
      'Não foi possível identificar o prestador para consultar o portal.';

  static const String filtroTodos = 'Todas';
  static const String filtroSenha = 'Senha';
  static const String filtroCarteira = 'Carteira';
  static const String filtroProcedimento = 'Procedimento';
  static const String filtroCrm = 'CRM';
  static const String filtroData = 'Data';
  static const String filtroSemResultado =
      'Nenhuma guia encontrada com este filtro.';
}
