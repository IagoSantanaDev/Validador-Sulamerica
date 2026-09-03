import '../../../../globals/constants/app_dimens.dart';
import 'package:flutter/material.dart';

import '../../../../globals/constants/app_colors.dart';
import '../../../../globals/constants/app_strings.dart';
import '../../../../globals/widgets/textos.dart';

class CabecalhoResultado extends StatelessWidget {
  const CabecalhoResultado({super.key, required this.identificador});

  final String identificador;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const TextoApp.titulo(AppStrings.resultadoTitulo),
        const SizedBox(height: AppDimens.itemIconeTop),
        TextoApp.detalhe(
          '(Identificador: $identificador)',
          cor: AppColors.textMuted,
        ),
      ],
    );
  }
}