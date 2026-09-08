import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimens.dart';
import 'textos.dart';

/// Aviso de status no estilo anotação de ficha: régua colorida na lateral
/// sobre papel, sem preenchimento colorido nem sombra — evita o cartão
/// "ícone + fundo tingido" repetido em qualquer dashboard genérico.
class PainelStatus extends StatelessWidget {
  const PainelStatus({
    super.key,
    required this.icone,
    required this.cor,
    required this.titulo,
    this.mensagem,
  });

  final IconData icone;
  final Color cor;
  final String titulo;
  final String? mensagem;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: cor, width: 4)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
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
                if (titulo.isNotEmpty) TextoApp.tituloMedio(titulo, cor: cor),
                if (mensagem != null) ...[
                  if (titulo.isNotEmpty)
                    const SizedBox(height: AppDimens.itemIconeTop),
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
