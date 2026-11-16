import 'package:material_ui/material_ui.dart';

import '../../../../globals/constants/app_colors.dart';
import '../../../../globals/constants/app_dimens.dart';
import '../../../../globals/constants/app_strings.dart';
import '../../../../globals/widgets/textos.dart';

class BarraProgressoEnvio extends StatelessWidget {
  const BarraProgressoEnvio({super.key, required this.nomeArquivo});

  final String nomeArquivo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: AppDimens.dropZoneMaxWidth,
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppDimens.dropZoneLarguraMax),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextoApp.detalhe(
                '${AppStrings.uploadEnviandoArquivo} $nomeArquivo...',
              ),
              const SizedBox(height: AppDimens.spaceSm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                child: SizedBox(
                  height: AppDimens.progressoAltura,
                  child: Stack(
                    children: [
                      Container(color: AppColors.track),
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: AppDimens.progressoFatorCheio,
                            child: Container(color: AppColors.petroleo),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
