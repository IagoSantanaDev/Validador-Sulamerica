import 'package:flutter/material.dart';
import '../../data/models/guia_validada.dart';

class GradeGuias extends StatelessWidget {
  const GradeGuias({
    super.key,
    required this.linhas,
    required this.aoSelecionar,
  });

  final List<dynamic> linhas;
  final Future<void> Function(GuiaValidada) aoSelecionar;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
