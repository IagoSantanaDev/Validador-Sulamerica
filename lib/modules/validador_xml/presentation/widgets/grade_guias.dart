import 'package:flutter/material.dart';

import '../../../../globals/constants/app_colors.dart';
import '../../../../globals/constants/app_dimens.dart';
import '../../../../globals/constants/app_strings.dart';
import '../../../../globals/widgets/botao_texto.dart';
import '../../../../globals/widgets/rotulo_valor.dart';
import '../../../../globals/widgets/textos.dart';
import '../../data/models/consulta_guia.dart';
import '../../data/models/guia_validada.dart';

/// Grade de guias invalidadas: borda fina em todas as células (linha ×
/// coluna), sem cantos arredondados, sem sombra e sem card por trás. Ao tocar
/// numa linha, abre um popup com as informações da guia (extraídas do XML e
/// da API), sem os erros.
class GradeGuias extends StatelessWidget {
  const GradeGuias({super.key, required this.guias});

  final List<GuiaValidada> guias;

  static const TableBorder _borda = TableBorder(
    top: BorderSide(color: AppColors.border, width: 1),
    bottom: BorderSide(color: AppColors.border, width: 1),
    left: BorderSide(color: AppColors.border, width: 1),
    right: BorderSide(color: AppColors.border, width: 1),
    horizontalInside: BorderSide(color: AppColors.border, width: 1),
    verticalInside: BorderSide(color: AppColors.border, width: 1),
  );

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(52),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(3),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: _borda,
      children: [
        const TableRow(
          children: [
            _Celula(texto: ''),
            _Celula(texto: AppStrings.rotuloGuia, cabecalho: true),
            _Celula(texto: 'Detalhes', cabecalho: true),
          ],
        ),
        for (final GuiaValidada guia in guias)
          TableRow(
            children: [
              _Celula(
                tap: () => _mostrarInformacoes(context, guia),
                child: const Center(
                  child: Icon(
                    Icons.cancel,
                    size: AppDimens.itemIcone,
                    color: AppColors.error,
                  ),
                ),
              ),
              _Celula(
                tap: () => _mostrarInformacoes(context, guia),
                child: SelectableText(
                  guia.numeroGuiaPrestador,
                  style: TextoApp.estiloDe(TextoEstilo.corpo)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _Celula(
                tap: () => _mostrarInformacoes(context, guia),
                child: _DetalheGuia(guia: guia),
              ),
            ],
          ),
      ],
    );
  }

  void _mostrarInformacoes(BuildContext context, GuiaValidada guia) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final GuiaValidada foco = guia;
        final String? nome = foco.guia.nomeBeneficiario;
        return AlertDialog(
          title: TextoApp.tituloMedio(
            '${AppStrings.rotuloGuia} ${foco.numeroGuiaPrestador}',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (nome != null && nome.isNotEmpty) ...[
                RotuloValor(rotulo: AppStrings.rotuloBeneficiario, valor: nome),
                const SizedBox(height: AppDimens.spaceXs),
              ],
              RotuloValor(
                rotulo: AppStrings.rotuloCarteira,
                valor: foco.numeroCarteira ?? AppStrings.valorIndisponivel,
              ),
              const SizedBox(height: AppDimens.spaceXs),
              RotuloValor(
                rotulo: AppStrings.rotuloSenha,
                valor: foco.senha ?? AppStrings.valorIndisponivel,
              ),
              if (foco.consulta case final ConsultaGuia consulta) ...[
                const SizedBox(height: AppDimens.spaceMd),
                RotuloValor(
                  rotulo: consulta.tipo == TipoConsultaGuia.elegibilidade
                      ? AppStrings.rotuloElegibilidade
                      : AppStrings.rotuloAutorizacaoVpp,
                  valor: consulta.descricao,
                ),
              ],
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

/// Célula da grade com bordas (o próprio TableBorder desenha), padding e,
/// quando há [tap], abre a linha. Sem fundo e sem cantos arredondados.
class _Celula extends StatelessWidget {
  const _Celula({
    this.texto,
    this.child,
    this.tap,
    this.cabecalho = false,
  }) : assert(texto != null || child != null);

  final String? texto;
  final Widget? child;
  final VoidCallback? tap;
  final bool cabecalho;

  @override
  Widget build(BuildContext context) {
    final Widget conteudo = child ??
        SelectableText(
          texto!,
          style: TextoApp.estiloDe(TextoEstilo.detalhe).copyWith(
            fontWeight: cabecalho ? FontWeight.w700 : FontWeight.w400,
            color: cabecalho ? AppColors.textMuted : null,
          ),
        );

    final Widget comPadding = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.itemPaddingV,
      ),
      child: conteudo,
    );

    if (tap == null) return comPadding;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tap,
      child: comPadding,
    );
  }
}

class _DetalheGuia extends StatelessWidget {
  const _DetalheGuia({required this.guia});

  final GuiaValidada guia;

  @override
  Widget build(BuildContext context) {
    final String mensagem =
        guia.erros.isNotEmpty ? guia.erros.first.mensagem : '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          mensagem,
          style: TextoApp.estiloDe(TextoEstilo.corpo).copyWith(height: 1.5),
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
    );
  }
}