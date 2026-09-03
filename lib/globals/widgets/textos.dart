import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

enum TextoEstilo { titulo, tituloMedio, corpo, detalhe, destaque }

class TextoApp extends StatelessWidget {
  const TextoApp._(
    this.texto,
    this._estilo, {
    super.key,
    this.cor,
    this.alinhamento,
    this.peso,
  });

  const TextoApp.titulo(
    String texto, {
    Key? key,
    Color? cor,
    TextAlign? alinhamento,
    FontWeight? peso,
  }) : this._(
          texto,
          TextoEstilo.titulo,
          key: key,
          cor: cor,
          alinhamento: alinhamento,
          peso: peso,
        );

  const TextoApp.tituloMedio(
    String texto, {
    Key? key,
    Color? cor,
    TextAlign? alinhamento,
    FontWeight? peso,
  }) : this._(
          texto,
          TextoEstilo.tituloMedio,
          key: key,
          cor: cor,
          alinhamento: alinhamento,
          peso: peso,
        );

  const TextoApp.corpo(
    String texto, {
    Key? key,
    Color? cor,
    TextAlign? alinhamento,
    FontWeight? peso,
  }) : this._(
          texto,
          TextoEstilo.corpo,
          key: key,
          cor: cor,
          alinhamento: alinhamento,
          peso: peso,
        );

  const TextoApp.detalhe(
    String texto, {
    Key? key,
    Color? cor,
    TextAlign? alinhamento,
    FontWeight? peso,
  }) : this._(
          texto,
          TextoEstilo.detalhe,
          key: key,
          cor: cor,
          alinhamento: alinhamento,
          peso: peso,
        );

  const TextoApp.destaque(
    String texto, {
    Key? key,
    Color? cor,
    TextAlign? alinhamento,
    FontWeight? peso,
  }) : this._(
          texto,
          TextoEstilo.destaque,
          key: key,
          cor: cor,
          alinhamento: alinhamento,
          peso: peso,
        );

  final String texto;
  final TextoEstilo _estilo;
  final Color? cor;
  final TextAlign? alinhamento;
  final FontWeight? peso;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      textAlign: alinhamento,
      style: _aplicar(_estilo, cor: cor, peso: peso),
    );
  }

  static TextStyle estiloDe(TextoEstilo estilo) =>
      _aplicar(estilo, cor: null, peso: null);

  static TextStyle _aplicar(
    TextoEstilo estilo, {
    Color? cor,
    FontWeight? peso,
  }) =>
      _estiloDe(estilo).copyWith(
        color: cor ?? _corPadrao(estilo),
        fontWeight: peso,
      );

  static TextStyle _estiloDe(TextoEstilo estilo) {
    switch (estilo) {
      case TextoEstilo.titulo:
        return const TextStyle(fontSize: 28, fontWeight: FontWeight.w700);
      case TextoEstilo.tituloMedio:
        return const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600);
      case TextoEstilo.corpo:
        return const TextStyle(fontSize: 15, fontWeight: FontWeight.w400);
      case TextoEstilo.detalhe:
        return const TextStyle(fontSize: 13, fontWeight: FontWeight.w400);
      case TextoEstilo.destaque:
        return const TextStyle(fontSize: 17, fontWeight: FontWeight.w600);
    }
  }

  static Color _corPadrao(TextoEstilo estilo) {
    switch (estilo) {
      case TextoEstilo.titulo:
      case TextoEstilo.tituloMedio:
      case TextoEstilo.corpo:
      case TextoEstilo.destaque:
        return AppColors.textPrimary;
      case TextoEstilo.detalhe:
        return AppColors.textMuted;
    }
  }
}