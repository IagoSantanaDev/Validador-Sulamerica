import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../globals/constants/app_colors.dart';
import '../../../../globals/constants/app_dimens.dart';
import '../../../../globals/constants/app_strings.dart';
import '../../../../globals/widgets/botao_texto.dart';
import '../../../../globals/widgets/card_surface.dart';
import '../../../../globals/widgets/icone_favicon.dart';
import '../../../../globals/widgets/painel_status.dart';
import '../../../../globals/widgets/textos.dart';
import '../controllers/validador_controller.dart';
import '../../data/models/guia_validada.dart';
import '../widgets/barra_progresso_envio.dart';
import '../widgets/cabecalho_resultado.dart';
import '../widgets/drop_zone_site.dart';
import '../widgets/grade_guias.dart';
import '../widgets/navbar_site.dart';
import '../widgets/rodape_resultado.dart';
import '../widgets/tabela_metadados.dart';

class ValidadorPage extends StatelessWidget {
  const ValidadorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ValidadorController(),
      child: const Scaffold(
        body: SafeArea(
          child: _ValidadorBody(),
        ),
      ),
    );
  }
}

class _ValidadorBody extends StatefulWidget {
  const _ValidadorBody();

  @override
  State<_ValidadorBody> createState() => _ValidadorBodyState();
}

class _ValidadorBodyState extends State<_ValidadorBody> {
  String? _ultimoValidadoNome;
  String? _identificador;

  TipoErroGuia? _filtroErro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ValidadorController>().verificarDisponibilidadeApi();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ValidadorController controller =
        context.watch<ValidadorController>();

    if (controller.nomeArquivo != null &&
        _ultimoValidadoNome != controller.nomeArquivo &&
        controller.status != StatusValidador.validando &&
        controller.status != StatusValidador.concluido) {
      _ultimoValidadoNome = controller.nomeArquivo;
      _identificador = _gerarIdentificador();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ValidadorController>().validar();
      });
    }

    return Column(
      children: [
        NavbarSite(onTituloTap: _voltarParaHome),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildConteudo(context, controller),
          ),
        ),
      ],
    );
  }

  Widget _buildConteudo(BuildContext context, ValidadorController c) {
    final EstadoConexao conexao = c.estadoConexao;
    if (conexao != EstadoConexao.pronto) {
      return _painelConexao(c, conexao);
    }

    if (c.status == StatusValidador.concluido) {
      return _buildResultado(context, c);
    }

    if (c.status == StatusValidador.arquivoPronto ||
        c.status == StatusValidador.validando) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: AppDimens.spaceXs),
          child: BarraProgressoEnvio(
            nomeArquivo: c.nomeArquivo ?? '',
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDimens.larguraMaximaHome,
          ),
          child: Padding(
            padding: const EdgeInsets.only(
              top: AppDimens.spaceSm,
              bottom: AppDimens.spaceXxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const IconeFavicon(tamanho: AppDimens.logoHomeSize),
                const SizedBox(height: AppDimens.spaceLg),
                const TextoApp.corpo(
                  AppStrings.jumbotronLegenda,
                  cor: AppColors.textMuted,
                  alinhamento: TextAlign.center,
                ),
                const SizedBox(height: AppDimens.spaceLg),
                DropZoneSite(
                  onArquivoSelecionado: (nome, bytes) =>
                      context.read<ValidadorController>().definirArquivo(
                            nomeArquivo: nome,
                            bytes: bytes,
                          ),
                ),
                if (c.status == StatusValidador.erro &&
                    c.mensagemErro != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppDimens.spaceLg),
                    child: PainelStatus(
                      icone: Icons.error_outline,
                      cor: AppColors.error,
                      titulo: AppStrings.falhaValidacaoTitulo,
                      mensagem: c.mensagemErro,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Gate de conexão: o site só funciona quando a API está acessível E o
  /// login no portal foi feito — qualquer falha bloqueia a validação e
  /// mostra o motivo exato (API_URL, credenciais ausentes ou inválidas).
  Widget _painelConexao(ValidadorController c, EstadoConexao conexao) {
    final (IconData icone, Color cor, String titulo, String mensagem,
            String? detalhe) =
        switch (conexao) {
      EstadoConexao.verificando => (
          Icons.sync,
          AppColors.primary,
          AppStrings.apiVerificandoTitulo,
          AppStrings.apiVerificandoMensagem,
          null,
        ),
      EstadoConexao.apiIndisponivel => (
          Icons.link_off,
          AppColors.error,
          AppStrings.apiIndisponivelTitulo,
          AppStrings.apiIndisponivelMensagem,
          AppStrings.apiIndisponivelDetalhe,
        ),
      EstadoConexao.credenciaisAusentes => (
          Icons.key_off,
          AppColors.error,
          AppStrings.apiCredenciaisAusentesTitulo,
          AppStrings.apiCredenciaisAusentesMensagem,
          AppStrings.apiCredenciaisDetalhe,
        ),
      EstadoConexao.credenciaisInvalidas => (
          Icons.lock_outline,
          AppColors.error,
          AppStrings.apiLoginFalhouTitulo,
          AppStrings.apiLoginFalhouMensagem,
          AppStrings.apiLoginFalhouDetalhe,
        ),
      EstadoConexao.pronto => (
          Icons.link,
          AppColors.success,
          '',
          '',
          null,
        ),
    };

    return Center(
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: AppDimens.larguraMaximaHome),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PainelStatus(
                icone: icone,
                cor: cor,
                titulo: titulo,
                mensagem: mensagem,
              ),
              if (detalhe != null) ...[
                const SizedBox(height: AppDimens.spaceSm),
                TextoApp.detalhe(
                  detalhe,
                  cor: AppColors.textMuted,
                  alinhamento: TextAlign.center,
                ),
                const SizedBox(height: AppDimens.spaceMd),
                BotaoTexto(
                  rotulo: AppStrings.apiTentarNovamente,
                  onPressed: () => c.verificarDisponibilidadeApi(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultado(BuildContext context, ValidadorController c) {
    final List<GuiaValidada> comProblema = c.guiasComErro;
    // Filtro opera por LINHA para não vazar erros de outro tipo.
    final List<LinhaGradeGuia> todasLinhas = [
      for (final GuiaValidada g in comProblema) ...linhasDeGuia(g),
    ];
    final List<LinhaGradeGuia> linhasFiltradas = _filtroErro == null
        ? todasLinhas
        : [
            for (final LinhaGradeGuia l in todasLinhas)
              if (tipoErroDeLinha(l) == _filtroErro) l,
          ];
    final List<LinhaGradeGuia> linhas = agruparPorDetalhe(linhasFiltradas);
    return SingleChildScrollView(
      key: const ValueKey('resultado'),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDimens.larguraMaximaResultado,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceLg,
              vertical: AppDimens.spaceXxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CabecalhoResultado(identificador: _identificador ?? AppStrings.valorIndisponivel),
                const SizedBox(height: AppDimens.spaceLg),
                CardSurface(
                  child: TabelaMetadados(
                    nomeArquivo: c.nomeArquivo,
                    tamanhoArquivoBytes: c.tamanhoArquivoBytes,
                    informacoes: c.informacoes,
                    hashMd5: c.hashMd5,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceLg),
                if (comProblema.isEmpty)
                  const PainelStatus(
                    icone: Icons.check_circle_outline,
                    cor: AppColors.success,
                    titulo: AppStrings.semErrosTitulo,
                    mensagem: AppStrings.semErrosDetalhe,
                  )
                else ...[
                  const _TituloLista(),
                  const SizedBox(height: AppDimens.spaceSm),
                  _filtroErros(),
                  const SizedBox(height: AppDimens.spaceSm),
                  if (linhas.isEmpty)
                    const PainelStatus(
                      icone: Icons.filter_alt_off,
                      cor: AppColors.textMuted,
                      titulo: '',
                      mensagem: AppStrings.filtroSemResultado,
                    )
                  else
                    GradeGuias(linhas: linhas),
                ],
                const SizedBox(height: AppDimens.spaceLg),
                RodapeResultado(
                  tempoProcessamento: c.tempoProcessamento,
                  onValidarOutro: () {
                    setState(() {
                      _ultimoValidadoNome = null;
                      _identificador = null;
                    });
                    context.read<ValidadorController>().novoArquivo();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filtroErros() {
    return Wrap(
      spacing: AppDimens.spaceSm,
      runSpacing: AppDimens.spaceXs,
      children: [
        _chipFiltro(
          rotulo: AppStrings.filtroTodos,
          selecionado: _filtroErro == null,
          onSelected: (_) => setState(() => _filtroErro = null),
        ),
        for (final TipoErroGuia tipo in TipoErroGuia.values)
          if (tipo != TipoErroGuia.credenciais)
            _chipFiltro(
              rotulo: rotuloTipoErro(tipo),
              selecionado: _filtroErro == tipo,
              onSelected: (_) => setState(() {
                _filtroErro = _filtroErro == tipo ? null : tipo;
              }),
            ),
      ],
    );
  }

  /// Cor do rótulo resolvida aqui (e não no ChipThemeData) porque
  /// labelStyle do tema não varia por estado nesta versão do Flutter.
  Widget _chipFiltro({
    required String rotulo,
    required bool selecionado,
    required ValueChanged<bool> onSelected,
  }) {
    return ChoiceChip(
      label: Text(
        rotulo,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selecionado ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: selecionado,
      onSelected: onSelected,
    );
  }

  String _gerarIdentificador() {
    final Random rng = Random.secure();
    final String hex = List<int>.generate(16, (_) => rng.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return hex;
  }

  void _voltarParaHome() {
    setState(() {
      _ultimoValidadoNome = null;
      _identificador = null;
      _filtroErro = null;
    });
    context.read<ValidadorController>().novoArquivo();
  }
}

class _TituloLista extends StatelessWidget {
  const _TituloLista();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: TextoApp.detalhe(
        AppStrings.validacoesPorGuia,
        peso: FontWeight.w700,
      ),
    );
  }
}