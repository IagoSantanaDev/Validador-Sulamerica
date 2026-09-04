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
  });

  final String rotulo;
  final String valor;
  final double? larguraRotulo;

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
          child: TextoApp.corpo(
            valor,
            cor: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}