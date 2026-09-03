import 'package:flutter/material.dart';

import '../../../../globals/constants/app_colors.dart';
import '../../../../globals/constants/app_dimens.dart';
import '../../../../globals/constants/app_strings.dart';
import '../../data/models/guia_validada.dart';

/// Uma linha representando uma ocorrência de guia validada.
///
/// [corDoGrupo] identifica visualmente ocorrências consecutivas com o
/// mesmo numeroGuiaPrestador; [primeiraDaSequencia] desenha uma borda
/// superior que separa uma sequência da outra, mesmo permanecendo cada
/// ocorrência em sua própria linha.
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
    return Container(
      margin: EdgeInsets.only(
        top: primeiraDaSequencia ? AppDimens.spaceMd : 0,
      ),
      decoration: BoxDecoration(
        color: corDoGrupo,
        border: Border(
          left: BorderSide(
            color: guiaValidada.temErro ? AppColors.error : AppColors.success,
            width: 4,
          ),
          top: primeiraDaSequencia
              ? const BorderSide(color: AppColors.border)
              : BorderSide.none,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIndicadorStatus(),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(child: _buildDetalhes(context)),
        ],
      ),
    );
  }

  Widget _buildIndicadorStatus() {
    final bool temErro = guiaValidada.temErro;
    return Tooltip(
      message: temErro ? AppStrings.statusErro : AppStrings.statusValido,
      child: Icon(
        temErro ? Icons.error_outline : Icons.check_circle_outline,
        color: temErro ? AppColors.error : AppColors.success,
        size: AppDimens.minTouchTarget / 2,
      ),
    );
  }

  Widget _buildDetalhes(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppDimens.spaceMd,
          children: [
            _buildCampo(
              context,
              AppStrings.rotuloNumeroGuia,
              guiaValidada.numeroGuiaPrestador,
            ),
            _buildCampo(
              context,
              AppStrings.rotuloNumeroCarteira,
              guiaValidada.numeroCarteira ?? '-',
            ),
          ],
        ),
        if (guiaValidada.temErro) ...[
          const SizedBox(height: AppDimens.spaceXs),
          ...guiaValidada.erros.map(
            (erro) => Text(
              '• ${erro.mensagem}',
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCampo(BuildContext context, String rotulo, String valor) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium,
        children: [
          TextSpan(
            text: '$rotulo: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: valor),
        ],
      ),
    );
  }
}
