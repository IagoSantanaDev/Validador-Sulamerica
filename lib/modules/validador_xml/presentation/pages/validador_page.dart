import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../globals/constants/app_colors.dart';
import '../../../../globals/constants/app_dimens.dart';
import '../../../../globals/constants/app_strings.dart';
import '../controllers/validador_controller.dart';
import '../widgets/drop_zone_widget.dart';
import '../widgets/resultado_lista_widget.dart';

class ValidadorPage extends StatelessWidget {
  const ValidadorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ValidadorController(),
      child: Scaffold(
        appBar: AppBar(title: const Text(AppStrings.tituloPagina)),
        body: const _ValidadorBody(),
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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppDimens.larguraMaximaConteudo,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Column(
            children: [
              DropZoneWidget(
                nomeArquivoAtual: controller.nomeArquivo,
                onArquivoSelecionado: (nome, bytes) =>
                    controller.definirArquivo(nomeArquivo: nome, bytes: bytes),
                onErroSelecao: (mensagem) => _mostrarErro(context, mensagem),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              _buildAcoes(controller),
              const SizedBox(height: AppDimens.spaceMd),
              if (controller.mensagemErro != null)
                _buildMensagemErro(controller.mensagemErro!),
              Expanded(child: _buildResultado(controller)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAcoes(ValidadorController controller) {
    final bool podeValidar = controller.status != StatusValidador.semArquivo &&
        controller.status != StatusValidador.validando;
    final bool estaValidando = controller.status == StatusValidador.validando;
    final bool concluido = controller.status == StatusValidador.concluido;

    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: podeValidar ? controller.validar : null,
          icon: estaValidando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.fact_check_outlined),
          label: Text(
            estaValidando ? AppStrings.mensagemValidando : AppStrings.botaoValidar,
          ),
        ),
        const SizedBox(width: AppDimens.spaceMd),
        if (concluido) ...[
          _buildResumo(controller),
          const Spacer(),
          _buildFiltroErros(controller),
        ],
      ],
    );
  }

  Widget _buildResumo(ValidadorController controller) {
    return Text(
      '${controller.totalGuias} guias · ${controller.totalGuiasComErro} com erro',
      style: const TextStyle(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildFiltroErros(ValidadorController controller) {
    return FilterChip(
      label: const Text(AppStrings.filtroMostrarSomenteErros),
      selected: controller.somenteErros,
      onSelected: controller.alternarSomenteErros,
    );
  }

  Widget _buildMensagemErro(String mensagem) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      child: Text(
        mensagem,
        style: const TextStyle(color: AppColors.error),
      ),
    );
  }

  Widget _buildResultado(ValidadorController controller) {
    if (controller.status != StatusValidador.concluido) {
      return const SizedBox.shrink();
    }
    return ResultadoListaWidget(guias: controller.resultadoFiltrado);
  }

  void _mostrarErro(BuildContext context, String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }
}
