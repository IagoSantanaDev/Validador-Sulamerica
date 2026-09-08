import 'package:flutter/material.dart';

import '../../../../globals/constants/app_colors.dart';
import '../../../../globals/constants/app_dimens.dart';
import '../../../../globals/constants/app_strings.dart';
import '../../../../globals/widgets/icone_favicon.dart';
import '../../../../globals/widgets/textos.dart';

/// Estilo papel timbrado: fundo claro (o símbolo não lê bem sobre navy) com
/// uma régua sólida na base, em vez da barra colorida cheia usual de SaaS.
class NavbarSite extends StatelessWidget {
  const NavbarSite({super.key, this.onTituloTap});

  final VoidCallback? onTituloTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.navbar,
      child: Container(
        width: double.infinity,
        height: AppDimens.navbarHeight,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.navy,
              width: AppDimens.navbarRegua,
            ),
          ),
        ),
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
                      cor: AppColors.navy,
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
