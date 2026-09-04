import 'package:flutter/material.dart';

import '../../../../globals/constants/app_colors.dart';
import '../../../../globals/constants/app_dimens.dart';
import '../../../../globals/constants/app_strings.dart';
import '../../../../globals/widgets/botao_texto.dart';
import '../../../../globals/widgets/rotulo_valor.dart';
import '../../../../globals/widgets/textos.dart';
import '../../data/models/consulta_guia.dart';
import '../../data/models/guia_validada.dart';

/// Categorias de erro usadas no filtro da grade.
enum TipoErroGuia { senha, carteira, elegibilidade, autorizacao, credenciais }

/// Categoriza o problema que uma guia representa (erro local ou de consulta).
/// Nulo quando a guia não tem problema.
TipoErroGuia? tipoErroDe(GuiaValidada guia) {
  final ConsultaGuia? consulta = guia.consulta;
  if (consulta != null && !consulta.sucesso) {
    final String descricao = consulta.descricao;
    if (descricao.contains('autenticar') ||
        descricao.contains('Credenciais') ||
        descricao.contains('credenciais')) {
      return TipoErroGuia.credenciais;
    }
    if (consulta.tipo == TipoConsultaGuia.elegibilidade) {
      if (descricao.contains('Carteira') || descricao.contains('carteira')) {
        return TipoErroGuia.carteira;
      }
      return TipoErroGuia.elegibilidade;
    }
    return TipoErroGuia.autorizacao;
  }
  if (guia.erros.any((e) => e.campo == 'senha')) {
    return TipoErroGuia.senha;
  }
  if (guia.erros.any((e) => e.campo == 'numeroCarteira')) {
    return TipoErroGuia.carteira;
  }
  return null;
}

String rotuloTipoErro(TipoErroGuia tipo) => switch (tipo) {
      TipoErroGuia.senha => AppStrings.filtroSenha,
      TipoErroGuia.carteira => AppStrings.filtroCarteira,
      TipoErroGuia.elegibilidade => AppStrings.filtroElegibilidade,
      TipoErroGuia.autorizacao => AppStrings.filtroAutorizacao,
      TipoErroGuia.credenciais => AppStrings.filtroCredenciais,
    };

/// Grade de guias invalidadas: borda fina em todas as células (linha ×
/// coluna), sem cantos arredondados, sem sombra e sem card por trás. A linha
/// inteira é clicável (texto e ícone), fica um pouco escura no hover e o
/// cursor vira de clique; o toque abre um popup com as informações da guia
/// (extraídas do XML e da API), sem os erros.
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
          _linha(context, guia),
      ],
    );
  }

  /// Linha da grade: as três células compartilham o estado de hover para a
  /// linha inteira escurecer junta; todas respondem ao clique.
  TableRow _linha(BuildContext context, GuiaValidada guia) {
    final ValueNotifier<bool> hover = ValueNotifier<bool>(false);
    return TableRow(
      children: [
        _Celula(
          hover: hover,
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
          hover: hover,
          tap: () => _mostrarInformacoes(context, guia),
          child: TextoApp.corpo(
            guia.numeroGuiaPrestador,
            peso: FontWeight.w700,
            selecionavel: false,
          ),
        ),
        _Celula(
          hover: hover,
          tap: () => _mostrarInformacoes(context, guia),
          child: TextoApp.corpo(
            guia.erros.isNotEmpty ? guia.erros.first.mensagem : '',
            selecionavel: false,
          ),
        ),
      ],
    );
  }

  void _mostrarInformacoes(BuildContext context, GuiaValidada guia) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final String? nome = guia.guia.nomeBeneficiario;
        return AlertDialog(
          title: TextoApp.tituloMedio(
            '${AppStrings.rotuloGuia} ${guia.numeroGuiaPrestador}',
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
                valor: guia.numeroCarteira ?? AppStrings.valorIndisponivel,
              ),
              const SizedBox(height: AppDimens.spaceXs),
              RotuloValor(
                rotulo: AppStrings.rotuloSenha,
                valor: guia.senha ?? AppStrings.valorIndisponivel,
              ),
              if (guia.consulta case final ConsultaGuia consulta) ...[
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

/// Célula da grade: borda desenhada pelo TableBorder, padding, feedback no
/// hover (fundo levemente escuro compartilhado com a linha), cursor de clique
/// e toda a área (incluindo texto/ícone) clicável quando há [tap].
class _Celula extends StatelessWidget {
  const _Celula({
    this.texto,
    this.child,
    this.tap,
    this.hover,
    this.cabecalho = false,
  }) : assert(texto != null || child != null);

  final String? texto;
  final Widget? child;
  final VoidCallback? tap;
  final ValueNotifier<bool>? hover;
  final bool cabecalho;

  @override
  Widget build(BuildContext context) {
    final Widget conteudo = child ??
        TextoApp.detalhe(
          texto!,
          peso: cabecalho ? FontWeight.w700 : FontWeight.w400,
          cor: cabecalho ? AppColors.textMuted : null,
          selecionavel: false,
        );

    if (tap == null || hover == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.itemPaddingV,
        ),
        child: conteudo,
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: hover!,
      builder: (context, ativo, _) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => hover!.value = true,
          onExit: (_) => hover!.value = false,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: tap,
            child: ColoredBox(
              color: ativo ? AppColors.hoverLinha : Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                  vertical: AppDimens.itemPaddingV,
                ),
                child: conteudo,
              ),
            ),
          ),
        );
      },
    );
  }
}