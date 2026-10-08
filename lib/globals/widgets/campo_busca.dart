import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimens.dart';

/// Campo de busca textual com contador de resultados.
///
/// Fica em `globals` por ser peça de UI reutilizável e livre de regra de
/// negócio: o total já vem filtrado de quem consome.
class CampoBusca extends StatefulWidget {
  const CampoBusca({
    super.key,
    required this.controller,
    required this.total,
    this.dica = '',
      this.focusNode,
    });

    final TextEditingController controller;
    final int total;
    final String dica;
    final FocusNode? focusNode;

  @override
  State<CampoBusca> createState() => _CampoBuscaState();
}

class _CampoBuscaState extends State<CampoBusca> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final bool preenchido = widget.controller.text.isNotEmpty;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppDimens.buscaLarguraMaxima,
          height: AppDimens.buscaAltura,
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimens.buscaRaio),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                                  focusNode: widget.focusNode,
                                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppDimens.spaceSm,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: AppDimens.buscaIconeTamanho,
                      color: AppColors.textMuted,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: AppDimens.buscaAltura - AppDimens.spaceSm,
                    ),
                    hintText: widget.dica,
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              if (preenchido)
                InkWell(
                  onTap: widget.controller.clear,
                  child: const Padding(
                    padding: EdgeInsets.only(
                      left: AppDimens.spaceXs,
                    ),
                    child: Icon(
                      Icons.cancel,
                      size: AppDimens.buscaIconeTamanho,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppDimens.spaceSm),
        _Contador(total: widget.total),
      ],
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimens.buscaAltura,
      constraints: const BoxConstraints(minWidth: AppDimens.buscaChipLargura),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimens.buscaRaio),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '$total',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
        ),
      ),
          );
        }
      }