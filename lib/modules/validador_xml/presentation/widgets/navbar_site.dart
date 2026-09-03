import 'package:flutter/material.dart';

import '../../../../globals/constants/app_colors.dart';
import '../../../../globals/constants/app_dimens.dart';
import '../../../../globals/constants/app_strings.dart';
import '../../../../globals/widgets/icone_favicon.dart';
import '../../../../globals/widgets/textos.dart';

class NavbarSite extends StatelessWidget {
  const NavbarSite({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: AppDimens.navbarHeight,
      color: AppColors.navbar,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
      child: const Row(
        children: [
          IconeFavicon(tamanho: AppDimens.navbarIconSize),
          SizedBox(width: AppDimens.spaceSm),
          TextoApp.destaque(
            AppStrings.tituloApp,
            cor: Colors.white,
          ),
          Spacer(),
        ],
      ),
    );
  }
}