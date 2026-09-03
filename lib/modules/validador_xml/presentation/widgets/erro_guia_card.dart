import 'package:flutter/material.dart';

import '../../../../globals/constants/app_colors.dart';
import '../../../../globals/constants/app_dimens.dart';
import '../../../../globals/constants/app_strings.dart';
import '../../../../globals/themes/app_theme.dart';
import '../../data/models/guia_validada.dart';

/// Uma linha representando uma ocorrência de guia — foco em quem tem erro
/// (a interface mostra apenas erros por padrão).
///
/// Visual limpo: chip de status à esquerda, campos com números tabulares
/// (sem layout shift) e cada erro em um tile de tom suave, sem bordas
/// (skill make-interfaces-feel-better).
class ErroGuiaCard extends StatelessWidget {
  const ErroGuiaCard({
    super.key,
    required this.guiaValidada,
    required this.corDoGrupo,
    required this.primeiraDaSequencia,
  });

  final GuiaValidada guiaValidada;
  final Color corDoGrupo;
  final bool primeiraDaSequencia;

  @override
  Widget build(BuildContext context) {
    final bool temErro = guiaValidada.temErro;

    return Container(
      margin: EdgeInsets.only(
        top: primeiraDaSequencia ? AppDimens.spaceMd : AppDimens.spaceSm,
      ),
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: corDoGrupo,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        boxShadow: AppTheme.sombraDeSurface(),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChipStatus(temErro: temErro),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: _DetalhesGuia(guiaValidada: guiaValidada),
          ),
        ],
      ),
    );
  }
}

class _ChipStatus extends StatelessWidget {
  const _ChipStatus({required this.temErro});

  final bool temErro;

  @override
  Widget build(BuildContext context) {
    final Color corBase = temErro ? AppColors.error : AppColors.success;
    final Color corFundo =
        temErro ? AppColors.errorBackground : AppColors.successBackground;

    return Tooltip(
      message: temErro ? AppStrings.statusErro : AppStrings.statusValido,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: corFundo,
          shape: BoxShape.circle,
        ),
        child: Icon(
          temErro ? Icons.error_outline : Icons.check_circle_outline,
          size: 20,
          color: corBase,
        ),
      ),
    );
  }
}

class _DetalhesGuia extends StatelessWidget {
  const _DetalhesGuia({required this.guiaValidada});

  final GuiaValidada guiaValidada;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppDimens.spaceLg,
          runSpacing: AppDimens.spaceXs,
          children: [
            _CampoValor(
              rotulo: AppStrings.rotuloNumeroGuia,
              valor: guiaValidada.numeroGuiaPrestador,
            ),
            _CampoValor(
              rotulo: AppStrings.rotuloNumeroCarteira,
              valor: guiaValidada.numeroCarteira ?? '-',
            ),
          ],
        ),
        if (guiaValidada.temErro) ...[
          const SizedBox(height: AppDimens.spaceSm + 2),
          ...guiaValidada.erros.map(
            (erro) => Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.spaceXs),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd - 2,
                  vertical: AppDimens.spaceXs + 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.errorBackground,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: Text(
                  '• ${erro.mensagem}',
                  style: const TextStyle(
                    color: AppColors.errorDark,
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CampoValor extends StatelessWidget {
  const _CampoValor({required this.rotulo, required this.valor});

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
        children: [
          TextSpan(
            text: '$rotulo: ',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          TextSpan(
            text: valor,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}