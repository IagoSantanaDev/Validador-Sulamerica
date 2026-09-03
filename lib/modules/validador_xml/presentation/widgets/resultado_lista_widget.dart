import 'package:flutter/material.dart';

import '../../../../globals/constants/app_colors.dart';
import '../../data/models/guia_validada.dart';
import 'erro_guia_card.dart';

/// Renderiza a lista de guias validadas — uma linha por ocorrência — e
/// atribui uma cor de fundo alternada a cada sequência consecutiva do
/// mesmo numeroGuiaPrestador, para que fiquem visualmente agrupadas sem
/// serem mescladas em uma única linha.
class ResultadoListaWidget extends StatelessWidget {
  const ResultadoListaWidget({super.key, required this.guias});

  final List<GuiaValidada> guias;

  @override
  Widget build(BuildContext context) {
    final List<int> indiceDoGrupo = _calcularIndiceDoGrupo();

    return ListView.builder(
      itemCount: guias.length,
      itemBuilder: (context, indice) {
        final bool primeiraDaSequencia = indice == 0 ||
            guias[indice - 1].numeroGuiaPrestador !=
                guias[indice].numeroGuiaPrestador;

        final Color corDoGrupo = AppColors.groupBackgrounds[
            indiceDoGrupo[indice] % AppColors.groupBackgrounds.length];

        return ErroGuiaCard(
          guiaValidada: guias[indice],
          corDoGrupo: corDoGrupo,
          primeiraDaSequencia: primeiraDaSequencia,
        );
      },
    );
  }

  /// Calcula, em uma única passada O(n), a qual sequência de
  /// numeroGuiaPrestador cada linha pertence — usado só para alternar cor.
  List<int> _calcularIndiceDoGrupo() {
    final List<int> grupos = List.filled(guias.length, 0);

    for (int i = 1; i < guias.length; i++) {
      final bool mesmaSequencia =
          guias[i].numeroGuiaPrestador == guias[i - 1].numeroGuiaPrestador;
      grupos[i] = mesmaSequencia ? grupos[i - 1] : grupos[i - 1] + 1;
    }

    return grupos;
  }
}
