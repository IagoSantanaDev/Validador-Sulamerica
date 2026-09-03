import 'package:flutter/material.dart';

import '../../../../globals/constants/app_colors.dart';
import '../../../../globals/constants/app_dimens.dart';
import '../../../../globals/constants/app_strings.dart';
import '../../../../globals/widgets/botao_texto.dart';
import '../../../../globals/widgets/rotulo_valor.dart';
import '../../../../globals/widgets/textos.dart';
import '../../data/models/guia_validada.dart';

class ItemValidacao extends StatelessWidget {
  const ItemValidacao({
    super.key,
    required this.indice,
    required this.guia,
  });

  final int indice;
  final GuiaValidada guia;

  @override
  Widget build(BuildContext context) {
    final String mensagem =
        guia.erros.isNotEmpty ? guia.erros.first.mensagem : '';

    return InkWell(
      onTap: () => _mostrarDetalhe(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.itemPaddingV,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NumeroBadge(numero: indice),
            const SizedBox(width: AppDimens.itemEspaco),
            const Padding(
              padding: EdgeInsets.only(top: AppDimens.itemIconeTop),
              child: Icon(
                Icons.warning_amber_rounded,
                size: AppDimens.itemIcone,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: mensagem,
                  style: TextoApp.estiloDe(TextoEstilo.corpo)
                      .copyWith(height: 1.5),
                  children: [
                    TextSpan(
                      text: AppStrings.entenderPorque,
                      style: TextoApp.estiloDe(TextoEstilo.detalhe),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDetalhe(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const TextoApp.tituloMedio(AppStrings.dialogoEntenda),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RotuloValor(
                rotulo: AppStrings.rotuloNumeroGuia,
                valor: guia.numeroGuiaPrestador,
              ),
              const SizedBox(height: AppDimens.spaceSm),
              RotuloValor(
                rotulo: AppStrings.rotuloNumeroCarteira,
                valor: guia.numeroCarteira ?? AppStrings.valorIndisponivel,
              ),
              const SizedBox(height: AppDimens.spaceMd),
              for (final erro in guia.erros)
                Padding(
                  padding: const EdgeInsets.only(top: AppDimens.spaceXs),
                  child: TextoApp.corpo('${erro.campo}: ${erro.mensagem}'),
                ),
            ],
          ),
          actions: [
            BotaoTexto(
              rotulo: AppStrings.dialogoFechar,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        );
      },
    );
  }
}

class _NumeroBadge extends StatelessWidget {
  const _NumeroBadge({required this.numero});

  final int numero;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimens.badgeTamanho,
      height: AppDimens.badgeTamanho,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: TextoApp.detalhe(
        '$numero',
        cor: Colors.white,
        peso: FontWeight.w700,
      ),
    );
  }
}