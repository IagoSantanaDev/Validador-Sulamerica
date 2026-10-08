import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'grade_guias_web.dart'
    if (dart.library.html) 'grade_guias_web.dart'
    if (dart.library.io) 'grade_guias_stub.dart' as web;
import '../../../../globals/constants/app_colors.dart';
import '../../../../globals/constants/app_dimens.dart';
import '../../../../globals/constants/app_strings.dart';
import '../../../../globals/widgets/botao_texto.dart';
import '../../../../globals/widgets/rotulo_valor.dart';
import '../../../../globals/widgets/textos.dart';
import '../../data/models/consulta_guia.dart';
import '../../data/models/guia_validada.dart';

enum TipoErroGuia { senha, carteira, procedimento, crm }

class LinhaGradeGuia {
  const LinhaGradeGuia({required this.guia, required this.detalhe});

  final GuiaValidada guia;
  final String detalhe;
}

List<LinhaGradeGuia> linhasDeGuia(GuiaValidada guia) {
  final List<LinhaGradeGuia> linhas = [
    for (final erro in guia.erros)
      LinhaGradeGuia(guia: guia, detalhe: erro.mensagem),
    for (final ConsultaGuia consulta in guia.consultas)
      if (!consulta.sucesso)
        LinhaGradeGuia(guia: guia, detalhe: consulta.descricao),
  ];
  return linhas;
}

List<LinhaGradeGuia> agruparPorDetalhe(List<LinhaGradeGuia> linhas) {
  final Map<String, List<LinhaGradeGuia>> grupos = {};
  for (final LinhaGradeGuia linha in linhas) {
    grupos.putIfAbsent(linha.detalhe, () => []).add(linha);
  }
  return [for (final List<LinhaGradeGuia> lista in grupos.values) ...lista];
}

TipoErroGuia? tipoErroDeLinha(LinhaGradeGuia linha) {
  final String detalhe = linha.detalhe;
  for (final ConsultaGuia consulta in linha.guia.consultas) {
    if (!consulta.sucesso && detalhe == consulta.descricao) {
      return _tipoDeConsulta(consulta);
    }
  }
  for (final erro in linha.guia.erros) {
    if (erro.mensagem != detalhe) continue;
    if (erro.campo == 'senha') return TipoErroGuia.senha;
    if (erro.campo == 'numeroCarteira') return TipoErroGuia.carteira;
    if (erro.campo == 'procedimentos') return TipoErroGuia.procedimento;
    if (erro.campo == 'crm') return TipoErroGuia.crm;
  }
  return null;
}

Set<TipoErroGuia> tiposErroDeLinha(LinhaGradeGuia linha) {
  final TipoErroGuia? tipo = tipoErroDeLinha(linha);
  if (tipo == null) return const {};

  final bool senhaVpp = tipo == TipoErroGuia.senha &&
      linha.guia.erros.any(
        (erro) =>
            erro.campo == 'senha' &&
            erro.mensagem == linha.detalhe &&
            erro.mensagem.startsWith('Senha obrigatória para procedimento(s):'),
      );
  if (senhaVpp) return {TipoErroGuia.senha, TipoErroGuia.procedimento};
  return {tipo};
}

TipoErroGuia _tipoDeConsulta(ConsultaGuia consulta) {
  return consulta.tipo == TipoConsultaGuia.senha
      ? TipoErroGuia.senha
      : TipoErroGuia.carteira;
}

String rotuloTipoErro(TipoErroGuia tipo) => switch (tipo) {
      TipoErroGuia.senha => AppStrings.filtroSenha,
      TipoErroGuia.carteira => AppStrings.filtroCarteira,
      TipoErroGuia.procedimento => AppStrings.filtroProcedimento,
      TipoErroGuia.crm => AppStrings.filtroCrm,
    };

class GradeGuias extends StatelessWidget {
  const GradeGuias({super.key, required this.linhas});

  final List<LinhaGradeGuia> linhas;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return web.GradeGuias(
        linhas: linhas,
        aoSelecionar: (guia) => _mostrarInformacoes(context, guia),
      );
    }

    return _GradeGuiasTable(
      linhas: linhas,
      aoSelecionar: (guia) => _mostrarInformacoes(context, guia),
    );
  }

  Future<void> _mostrarInformacoes(
    BuildContext context,
    GuiaValidada guia,
  ) async {
    await showDialog<void>(
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
                monoespacado: true,
              ),
              const SizedBox(height: AppDimens.spaceXs),
              RotuloValor(
                rotulo: AppStrings.rotuloSenha,
                valor: guia.senha ?? AppStrings.valorIndisponivel,
                monoespacado: true,
              ),
              for (final erro in guia.erros) ...[
                const SizedBox(height: AppDimens.spaceMd),
                Builder(
                  builder: (ctx) {
                    String valor = erro.mensagem;
                    if (erro.campo == 'procedimentos') {
                      final pList = guia.guia.procedimentos
                          .where((p) => erro.mensagem.contains(p.codigo));
                      if (pList.isNotEmpty) {
                        final p = pList.first;
                        valor = '${p.codigo} = ${p.quantidade}';
                      }
                    }
                    return RotuloValor(
                      rotulo: erro.campo == 'procedimentos'
                          ? AppStrings.filtroProcedimento
                          : erro.campo == 'senha'
                              ? AppStrings.rotuloSenha
                              : erro.campo == 'crm'
                                  ? AppStrings.filtroCrm
                                  : AppStrings.rotuloCarteira,
                      valor: valor,
                    );
                  },
                ),
              ],
              for (final ConsultaGuia consulta in guia.consultas) ...[
                const SizedBox(height: AppDimens.spaceMd),
                RotuloValor(
                  rotulo: consulta.tipo == TipoConsultaGuia.elegibilidade
                      ? AppStrings.rotuloElegibilidade
                      : AppStrings.rotuloSenha,
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

class _GradeGuiasTable extends StatelessWidget {
  const _GradeGuiasTable({
    required this.linhas,
    required this.aoSelecionar,
  });

  final List<LinhaGradeGuia> linhas;
  final ValueChanged<GuiaValidada> aoSelecionar;

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
            _Celula(texto: AppStrings.rotuloDetalhes, cabecalho: true),
          ],
        ),
        for (final LinhaGradeGuia linha in linhas) _linha(linha),
      ],
    );
  }

  TableRow _linha(LinhaGradeGuia linha) {
    final ValueNotifier<bool> hover = ValueNotifier<bool>(false);
    final GuiaValidada guia = linha.guia;
    return TableRow(
      children: [
        _Celula(
          hover: hover,
          tap: () => aoSelecionar(guia),
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
          tap: () => aoSelecionar(guia),
          child: TextoApp.corpo(
            guia.numeroGuiaPrestador,
            peso: FontWeight.w700,
          ),
        ),
        _Celula(
          hover: hover,
          tap: () => aoSelecionar(guia),
          child: TextoApp.corpo(
            linha.detalhe,
          ),
        ),
      ],
    );
  }
}

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
