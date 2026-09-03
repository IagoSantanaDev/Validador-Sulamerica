import 'package:flutter/material.dart';

import '../constants/app_dimens.dart';
import 'textos.dart';

class PainelStatus extends StatelessWidget {
  const PainelStatus({
    super.key,
    required this.icone,
    required this.cor,
    required this.corFundo,
    required this.titulo,
    this.mensagem,
  });

  final IconData icone;
  final Color cor;
  final Color corFundo;
  final String titulo;
  final String? mensagem;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: AppDimens.painelIcone, color: cor),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextoApp.tituloMedio(titulo, cor: cor),
                if (mensagem != null) ...[
                  const SizedBox(height: AppDimens.spaceXs),
                  TextoApp.corpo(mensagem!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}