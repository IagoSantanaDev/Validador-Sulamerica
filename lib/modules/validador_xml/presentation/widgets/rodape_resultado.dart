import 'package:flutter/material.dart';

import '../../../../globals/constants/app_strings.dart';
import '../../../../globals/widgets/botao_texto.dart';
import '../../../../globals/widgets/textos.dart';

class RodapeResultado extends StatelessWidget {
  const RodapeResultado({
    super.key,
    required this.tempoProcessamento,
    required this.onValidarOutro,
  });

  final Duration tempoProcessamento;
  final VoidCallback onValidarOutro;

  @override
  Widget build(BuildContext context) {
    final double segundos = tempoProcessamento.inMilliseconds / 1000.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextoApp.detalhe(
          '${AppStrings.processadoEmPrefix}'
          '${segundos.toStringAsFixed(3)}'
          '${AppStrings.processadoEmSufix}',
        ),
        BotaoTexto(
          rotulo: AppStrings.validarOutroArquivo,
          onPressed: onValidarOutro,
        ),
      ],
    );
  }
}