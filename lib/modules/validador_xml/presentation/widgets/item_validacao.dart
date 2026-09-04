import 'package:flutter/material.dart';

import '../../../../globals/constants/app_colors.dart';
import '../../../../globals/constants/app_dimens.dart';
import '../../../../globals/widgets/textos.dart';
import '../../data/models/consulta_guia.dart';
import '../../data/models/guia_validada.dart';

class ItemValidacao extends StatelessWidget {
  const ItemValidacao({super.key, required this.guia});

  final GuiaValidada guia;

  @override
  Widget build(BuildContext context) {
    final String mensagem =
        guia.erros.isNotEmpty ? guia.erros.first.mensagem : '';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.itemPaddingV,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: AppDimens.itemIconeTop),
            child: Icon(
              Icons.cancel,
              size: AppDimens.itemIcone,
              color: AppColors.error,
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          _NumeroGuia(numero: guia.numeroGuiaPrestador),
          const SizedBox(width: AppDimens.itemEspaco),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  mensagem,
                  style: TextoApp.estiloDe(TextoEstilo.corpo)
                      .copyWith(height: 1.5),
                ),
                if (guia.consulta case final ConsultaGuia consulta)
                  Padding(
                    padding: const EdgeInsets.only(top: AppDimens.spaceXs),
                    child: TextoApp.detalhe(
                      consulta.descricao,
                      cor: consulta.sucesso
                          ? AppColors.success
                          : AppColors.error,
                      peso: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NumeroGuia extends StatelessWidget {
  const _NumeroGuia({required this.numero});

  final String numero;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.all(Radius.circular(AppDimens.radiusMd)),
      ),
      alignment: Alignment.center,
      child: TextoApp.detalhe(
        numero,
        cor: Colors.white,
        peso: FontWeight.w700,
      ),
    );
  }
}