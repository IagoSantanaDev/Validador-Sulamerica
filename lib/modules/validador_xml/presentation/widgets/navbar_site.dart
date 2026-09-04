import 'package:flutter/material.dart';

import '../../../../globals/constants/app_colors.dart';
import '../../../../globals/constants/app_dimens.dart';
import '../../../../globals/constants/app_strings.dart';
import '../../../../globals/widgets/icone_favicon.dart';
import '../../../../globals/widgets/textos.dart';

class NavbarSite extends StatelessWidget {
  const NavbarSite({super.key, this.onTituloTap});

  final VoidCallback? onTituloTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.navbar,
      child: SizedBox(
        width: double.infinity,
        height: AppDimens.navbarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
          child: Row(
            children: [
              InkWell(
                onTap: onTituloTap,
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconeFavicon(tamanho: AppDimens.navbarIconSize),
                    SizedBox(width: AppDimens.spaceSm),
                    TextoApp.destaque(
                      AppStrings.tituloApp,
                      cor: Colors.white,
                      selecionavel: false,
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}