import 'package:flutter/material.dart';

/// Paleta ancorada nas duas únicas cores que já existiam no produto (o navy
/// e o verde-azulado do símbolo em web/favicon.ico) e no papel de ficha de
/// conferência/protocolo — não no azul-acinzentado e laranja genéricos de
/// dashboard que estavam aqui antes.
class AppColors {
  const AppColors._();

  static const Color navy = Color(0xFF0E3A63);
  static const Color petroleo = Color(0xFF0E8377);

  // "primary" e "navbar" seguem existindo como apelidos porque vários
  // widgets já dependem desses nomes; ambos apontam para o navy do símbolo.
  static const Color primary = navy;
  static const Color navbar = surface;

  static const Color background = Color(0xFFEEF2EE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF3F6F2);
  static const Color track = Color(0xFFE2E9E1);

  static const Color textPrimary = Color(0xFF16232B);
  static const Color textMuted = Color(0xFF5B6660);
  static const Color textLight = Color(0xFF3D4A44);

  static const Color border = Color(0xFFC9D3C8);

  static const Color error = Color(0xFF9C3B2E);
  static const Color success = petroleo;

  static const Color hoverLinha = Color(0x14163229);
}