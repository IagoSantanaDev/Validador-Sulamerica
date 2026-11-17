import 'package:material_ui/material_ui.dart';

import '../../../../globals/constants/app_colors.dart';
import '../../../../globals/constants/app_dimens.dart';
import '../../../../globals/widgets/textos.dart';

class BarraProgressoEnvio extends StatelessWidget {
  const BarraProgressoEnvio({super.key, required this.textoEtapa});

  final String textoEtapa;

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
              TextoApp.detalhe(textoEtapa, alinhamento: TextAlign.center),
              const SizedBox(height: AppDimens.spaceSm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                child: SizedBox(
                  height: AppDimens.progressoAltura,
                  child: LinearProgressIndicator(
                    value: null,
                    minHeight: AppDimens.progressoAltura,
                    color: AppColors.petroleo,
                    backgroundColor: AppColors.track,
                    semanticsLabel: textoEtapa,
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
