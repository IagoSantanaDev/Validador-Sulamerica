class AppStrings {
  const AppStrings._();

  static const String tituloApp = 'Validador TISS';
  static const String valorIndisponivel = '—';
  static const String mensagemArquivoInvalidoExtensao =
      'Selecione um arquivo com extensão .xml';

  static const String jumbotronLegenda =
      'Validação online de arquivos XML no padrão TISS da ANS.';
  static const String dropZoneTexto =
      'Clique aqui para selecionar o arquivo ou arraste ele para cá para iniciar a validação.';
  static const String uploadEnviandoArquivo = 'Enviando arquivo';

  static const String resultadoTitulo = 'Resultado da Validação';
  static const String processadoEmPrefix = 'Processado em ';
  static const String processadoEmSufix = ' segundos';
  static const String validarOutroArquivo = 'Validar outro arquivo';
  static const String validacoesPorGuia = 'Validações por guia';

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
  static const String rotuloCarteira = 'Carteira';
  static const String rotuloSenha = 'Senha';
  static const String rotuloBeneficiario = 'Beneficiário';
  static const String rotuloElegibilidade = 'Elegibilidade';
  static const String rotuloAutorizacaoVpp = 'Autorização VPP';
  static const String dialogoFechar = 'Fechar';

  static const String apiVerificandoTitulo = 'Conectando à API';
  static const String apiVerificandoMensagem =
      'Verificando conexão e autenticando no portal...';
  static const String apiIndisponivelTitulo = 'API indisponível';
  static const String apiIndisponivelMensagem =
      'Não foi possível conectar ao servidor intermediário.';
  static const String apiIndisponivelDetalhe =
      'Confira se a variável API_URL está configurada no build '
      '(ex.: API_URL=https://seu-backend.onrender.com).';
  static const String apiCredenciaisAusentesTitulo = 'Credenciais não configuradas';
  static const String apiCredenciaisAusentesMensagem =
      'PORTAL_CODE, PORTAL_USER e PORTAL_SENHA não estão definidos '
      'no build da aplicação.';
  static const String apiCredenciaisDetalhe =
      'Defina PORTAL_CODE, PORTAL_USER e PORTAL_SENHA nas variáveis de '
      'ambiente do build (Cloudflare Pages → Environment variables).';
  static const String apiLoginFalhouTitulo = 'Falha no login no portal';
  static const String apiLoginFalhouMensagem =
      'As credenciais foram rejeitadas pelo portal. Confira '
      'PORTAL_CODE, PORTAL_USER e PORTAL_SENHA.';
  static const String apiLoginFalhouDetalhe =
      'Confira os valores das variáveis PORTAL_* e tente novamente.';
  static const String apiTentarNovamente = 'Tentar novamente';

  static const String erroCarteiraInvalida =
      'Número da carteira inválido (deve ter 20 dígitos) e não foi consultado';
  static const String erroNaoElegivel = 'Beneficiário não elegível';
  static const String erroCarteiraNaoEncontrada = 'Carteira não encontrada';
  static const String erroVppSenhaInvalida = 'Autorização VPP: senha inválida';
  static const String erroLoginFalhou =
      'Falha ao autenticar no portal (confira PORTAL_CODE/USER/SENHA).';
  static const String erroCredenciaisAusentes =
      'Credenciais do portal não configuradas (PORTAL_CODE/USER/SENHA).';

  static const String filtroTodos = 'Todas';
  static const String filtroSenha = 'Senha';
  static const String filtroCarteira = 'Carteira';
  static const String filtroElegibilidade = 'Elegibilidade';
  static const String filtroAutorizacao = 'Autorização';
  static const String filtroCredenciais = 'Credenciais';
  static const String filtroSemResultado = 'Nenhuma guia encontrada com este filtro.';
}