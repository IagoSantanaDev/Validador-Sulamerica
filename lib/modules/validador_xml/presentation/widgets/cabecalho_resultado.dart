import 'package:material_ui/material_ui.dart';

import '../../../../globals/constants/app_colors.dart';
import '../../../../globals/constants/app_dimens.dart';
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
        const SizedBox(height: AppDimens.spaceSm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceSm,
            vertical: AppDimens.itemIconeTop,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TextoApp.detalhe(
                '${AppStrings.protocoloRotulo} ',
                cor: AppColors.textMuted,
                selecionavel: false,
              ),
              TextoApp.codigo(identificador, cor: AppColors.textPrimary),
            ],
          ),
        ),
      ],
    );
  }
}
