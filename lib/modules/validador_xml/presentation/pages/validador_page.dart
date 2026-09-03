import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../globals/constants/app_colors.dart';
import '../../../../globals/constants/app_dimens.dart';
import '../../../../globals/constants/app_strings.dart';
import '../../../../globals/widgets/card_surface.dart';
import '../../../../globals/widgets/icone_favicon.dart';
import '../../../../globals/widgets/painel_status.dart';
import '../../../../globals/widgets/textos.dart';
import '../controllers/validador_controller.dart';
import '../widgets/barra_progresso_envio.dart';
import '../widgets/cabecalho_resultado.dart';
import '../widgets/drop_zone_site.dart';
import '../widgets/footer_site.dart';
import '../widgets/item_validacao.dart';
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
        const NavbarSite(),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildConteudo(context, controller),
          ),
        ),
        const FooterSite(),
      ],
    );
  }

  Widget _buildConteudo(BuildContext context, ValidadorController c) {
    if (c.status == StatusValidador.concluido) {
      return _buildResultado(context, c);
    }

    return SingleChildScrollView(
      child: Center(
        child: CardSurface(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceXl,
            vertical: AppDimens.spaceXxl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimens.larguraMaximaHome,
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
                const SizedBox(height: AppDimens.spaceMd),
                if (c.status == StatusValidador.validando ||
                    c.status == StatusValidador.arquivoPronto)
                  Padding(
                    padding: const EdgeInsets.only(top: AppDimens.spaceMd),
                    child: BarraProgressoEnvio(
                      nomeArquivo: c.nomeArquivo ?? '',
                    ),
                  ),
                if (c.status == StatusValidador.erro &&
                    c.mensagemErro != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppDimens.spaceLg),
                    child: PainelStatus(
                      icone: Icons.error_outline,
                      cor: AppColors.error,
                      corFundo: AppColors.errorBackground,
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

  Widget _buildResultado(BuildContext context, ValidadorController c) {
    final guias = c.guiasComErro;
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
                if (guias.isEmpty)
                  const PainelStatus(
                    icone: Icons.check_circle_outline,
                    cor: AppColors.success,
                    corFundo: AppColors.successBackground,
                    titulo: AppStrings.semErrosTitulo,
                    mensagem: AppStrings.semErrosDetalhe,
                  )
                else
                  CardSurface(
                    child: Column(
                      children: [
                        const _TituloLista(),
                        for (int i = 0; i < guias.length; i++)
                          ItemValidacao(indice: i + 1, guia: guias[i]),
                      ],
                    ),
                  ),
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

  String _gerarIdentificador() {
    final Random rng = Random.secure();
    final String hex = List<int>.generate(16, (_) => rng.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return hex;
  }
}

class _TituloLista extends StatelessWidget {
  const _TituloLista();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      color: AppColors.surfaceMuted,
      child: const TextoApp.detalhe(
        AppStrings.validacoesPorGuia,
        peso: FontWeight.w700,
      ),
    );
  }
}