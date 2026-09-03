import 'package:flutter/material.dart';

import '../../../../globals/constants/app_colors.dart';
import '../../../../globals/constants/app_dimens.dart';
import '../../../../globals/constants/app_strings.dart';
import '../../../../globals/widgets/textos.dart';

class FooterSite extends StatelessWidget {
  const FooterSite({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: AppDimens.footerHeight,
      color: AppColors.footer,
      alignment: Alignment.center,
      child: const TextoApp.detalhe(
        AppStrings.footerCopyright,
        cor: AppColors.textMuted,
      ),
    );
  }
}