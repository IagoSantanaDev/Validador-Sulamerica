import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimens.dart';
import 'textos.dart';

class RotuloValor extends StatelessWidget {
  const RotuloValor({
    super.key,
    required this.rotulo,
    required this.valor,
    this.larguraRotulo,
    this.monoespacado = false,
  });

  final String rotulo;
  final String valor;
  final double? larguraRotulo;

  final bool monoespacado;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: larguraRotulo ?? AppDimens.rotuloLarguraPadrao,
          child: TextoApp.corpo(rotulo, cor: AppColors.textMuted),
        ),
        Expanded(
          child: monoespacado
              ? TextoApp.codigo(valor, cor: AppColors.textPrimary)
              : TextoApp.corpo(valor, cor: AppColors.textPrimary),
        ),
      ],
    );
  }
}
