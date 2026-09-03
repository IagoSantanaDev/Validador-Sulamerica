import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../globals/constants/app_colors.dart';
import '../../../../globals/constants/app_dimens.dart';
import '../../../../globals/constants/app_strings.dart';
import '../../../../globals/themes/app_theme.dart';
import '../controllers/validador_controller.dart';
import '../widgets/drop_zone_widget.dart';
import '../widgets/resultado_lista_widget.dart';

/// Tela principal — validação online de arquivos XML no padrão TISS.
///
/// Layout simples e funcional (inspirado no exemplo de referência):
/// título centralizado, drop zone como área principal e, após a validação,
/// um painel "Resultado da Validação" com os metadados do arquivo seguido
/// apenas das guias com erro (o lote válido não é exibido).
class ValidadorPage extends StatelessWidget {
  const ValidadorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ValidadorController(),
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 720,
              ),
              child: const _ValidadorBody(),
            ),
          ),
        ),
      ),
    );
  }
}

class _ValidadorBody extends StatelessWidget {
  const _ValidadorBody();

  @override
  Widget build(BuildContext context) {
    final ValidadorController controller =
        context.watch<ValidadorController>();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceLg,
        vertical: AppDimens.spaceXxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.tituloPagina,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            AppStrings.subtituloPagina,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.spaceLg),
          DropZoneWidget(
            nomeArquivoAtual: controller.nomeArquivo,
            tamanhoArquivoBytes: controller.tamanhoArquivoBytes,
            onArquivoSelecionado: (nome, bytes) =>
                controller.definirArquivo(nomeArquivo: nome, bytes: bytes),
            onErroSelecao: (mensagem) => _mostrarErro(context, mensagem),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Center(child: _buildBotaoValidar(controller)),
          const SizedBox(height: AppDimens.spaceLg),
          if (controller.status == StatusValidador.erro)
            _CardFalha(mensagem: controller.mensagemErro ?? ''),
          if (controller.status == StatusValidador.concluido) ...[
            _PainelResultado(controller: controller),
            const SizedBox(height: AppDimens.spaceMd),
            Expanded(child: _buildResultado(controller)),
          ],
        ],
      ),
    );
  }

  Widget _buildBotaoValidar(ValidadorController controller) {
    final bool podeValidar =
        controller.status != StatusValidador.semArquivo &&
            controller.status != StatusValidador.validando;
    final bool estaValidando =
        controller.status == StatusValidador.validando;

    return ElevatedButton.icon(
      onPressed: podeValidar ? controller.validar : null,
      icon: estaValidando
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.play_arrow_rounded, size: 20),
      label: Text(
        estaValidando
            ? AppStrings.mensagemValidando
            : AppStrings.botaoValidar,
      ),
    );
  }

  Widget _buildResultado(ValidadorController controller) {
    final guias = controller.guiasComErro;
    if (guias.isEmpty) {
      return const _CardSemErros();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animacao) =>
          FadeTransition(opacity: animacao, child: child),
      child: ResultadoListaWidget(
        key: const ValueKey('resultado'),
        guias: guias,
      ),
    );
  }

  void _mostrarErro(BuildContext context, String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }
}

// ---------- painel do resultado ----------

class _PainelResultado extends StatelessWidget {
  const _PainelResultado({required this.controller});

  final ValidadorController controller;

  @override
  Widget build(BuildContext context) {
    final int comErro = controller.totalGuiasComErro;
    final bool temErro = comErro > 0;

    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        boxShadow: AppTheme.sombraDeSurface(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.resultadoTitulo,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Icon(
                temErro ? Icons.error_outline : Icons.check_circle_outline,
                size: 20,
                color: temErro ? AppColors.error : AppColors.success,
              ),
              const SizedBox(width: AppDimens.spaceXs + 2),
              Text(
                temErro ? '$comErro erro(s)' : 'lote ok',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: temErro ? AppColors.error : AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const Divider(height: 20),
          Wrap(
            spacing: AppDimens.spaceLg + 4,
            runSpacing: AppDimens.spaceXs + 2,
            children: [
              _Metadado(
                rotulo: AppStrings.rotuloNomeArquivo,
                valor: controller.nomeArquivo ?? '-',
              ),
              _Metadado(
                rotulo: AppStrings.rotuloTamanhoArquivo,
                valor: _formatarTamanho(controller.tamanhoArquivoBytes),
              ),
              const _Metadado(
                rotulo: AppStrings.rotuloTipoGuia,
                valor: AppStrings.valorTipoGuia,
              ),
              _Metadado(
                rotulo: AppStrings.rotuloQtdGuias,
                valor: '${controller.totalGuias}',
              ),
              _Metadado(
                rotulo: AppStrings.rotuloComErro,
                valor: '$comErro',
                destaque: temErro,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatarTamanho(int? bytes) {
    if (bytes == null) return '-';
    if (bytes < 1024) return '$bytes B';
    final double kb = bytes / 1024;
    return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  }
}

class _Metadado extends StatelessWidget {
  const _Metadado({
    required this.rotulo,
    required this.valor,
    this.destaque = false,
  });

  final String rotulo;
  final String valor;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11.5,
                letterSpacing: 0.2,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                color: destaque
                    ? AppColors.error
                    : AppColors.textPrimary,
              ),
        ),
      ],
    );
  }
}

// ---------- estados ----------

class _CardSemErros extends StatelessWidget {
  const _CardSemErros();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceLg,
        vertical: AppDimens.spaceXxl,
      ),
      decoration: BoxDecoration(
        color: AppColors.successBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 28,
            color: AppColors.success,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            AppStrings.semErrosTitulo,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            AppStrings.semErrosDetalhe,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CardFalha extends StatelessWidget {
  const _CardFalha({required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.feedback_outlined,
            size: 20,
            color: AppColors.error,
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.falhaValidacaoTitulo,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.errorDark,
                      ),
                ),
                const SizedBox(height: AppDimens.spaceXs),
                Text(
                  mensagem,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}