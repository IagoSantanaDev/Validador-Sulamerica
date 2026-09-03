import 'package:flutter/material.dart';

import '../../../../globals/constants/app_colors.dart';
import '../../data/models/guia_validada.dart';
import 'erro_guia_card.dart';

/// Renderiza a lista de guias validadas — uma linha por ocorrência. A cada
/// sequência do mesmo numeroGuiaPrestador é aplicado um fundo levemente
/// alternado (quase imperceptível) para agrupar visualmente sem juntar as
/// linhas.
///
/// Entrada em stagger (skill make-interfaces-feel-better): fade + slide de
/// ~8px com 60ms de intervalo, easeOutCubic.
class ResultadoListaWidget extends StatefulWidget {
  const ResultadoListaWidget({super.key, required this.guias});

  final List<GuiaValidada> guias;

  @override
  State<ResultadoListaWidget> createState() => _ResultadoListaWidgetState();
}

class _ResultadoListaWidgetState extends State<ResultadoListaWidget> {
  static const Duration _duracao = Duration(milliseconds: 240);
  static const Duration _intervalo = Duration(milliseconds: 60);

  @override
  Widget build(BuildContext context) {
    final List<int> indiceDoGrupo = _calcularIndiceDoGrupo();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: widget.guias.length,
      itemBuilder: (context, indice) {
        final bool primeiraDaSequencia = indice == 0 ||
            widget.guias[indice - 1].numeroGuiaPrestador !=
                widget.guias[indice].numeroGuiaPrestador;

        final Color corDoGrupo = AppColors.groupBackgrounds[
            indiceDoGrupo[indice] % AppColors.groupBackgrounds.length];

        return _EntradaComStagger(
          atraso: Duration(
            milliseconds: indice * _intervalo.inMilliseconds,
          ),
          duracao: _duracao,
          child: ErroGuiaCard(
            guiaValidada: widget.guias[indice],
            corDoGrupo: corDoGrupo,
            primeiraDaSequencia: primeiraDaSequencia,
          ),
        );
      },
    );
  }

  /// Calcula, em uma única passada O(n), a qual sequência de
  /// numeroGuiaPrestador cada linha pertence — usado só para alternar cor.
  List<int> _calcularIndiceDoGrupo() {
    final List<int> grupos = List.filled(widget.guias.length, 0);

    for (int i = 1; i < widget.guias.length; i++) {
      final bool mesmaSequencia = widget.guias[i].numeroGuiaPrestador ==
          widget.guias[i - 1].numeroGuiaPrestador;
      grupos[i] = mesmaSequencia ? grupos[i - 1] : grupos[i - 1] + 1;
    }

    return grupos;
  }
}

/// Anima a entrada de um item com fade + pequeno slide, atrasado por
/// [atraso] para criar o efeito de stagger.
class _EntradaComStagger extends StatefulWidget {
  const _EntradaComStagger({
    required this.atraso,
    required this.duracao,
    required this.child,
  });

  final Duration atraso;
  final Duration duracao;
  final Widget child;

  @override
  State<_EntradaComStagger> createState() => _EntradaComStaggerState();
}

class _EntradaComStaggerState extends State<_EntradaComStagger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duracao,
    );
    Future<void>.delayed(widget.atraso, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> animacao = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    return FadeTransition(
      opacity: animacao,
      child: SlideTransition(
        position:
            Tween<Offset>(begin: const Offset(0, 0.025), end: Offset.zero)
                .animate(animacao),
        child: widget.child,
      ),
    );
  }
}