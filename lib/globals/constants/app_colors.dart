import 'package:flutter/material.dart';

/// Paleta de cores centralizada do app. Evita cores "mágicas" espalhadas
/// pela UI (ver regra "Sem magic numbers" do padrão do projeto).
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF0A5C36);
  static const Color primaryDark = Color(0xFF063F25);
  static const Color primarySoft = Color(0xFFE6F2EC);
  static const Color background = Color(0xFFF5F7F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF7F9F8);
  static const Color error = Color(0xFFD32F2F);
  static const Color errorDark = Color(0xFFB02626);
  static const Color errorBackground = Color(0xFFFBEDED);
  static const Color success = Color(0xFF2E7D32);
  static const Color successBackground = Color(0xFFEAF7ED);
  static const Color border = Color(0xFFE0E4E2);
  static const Color borderStrong = Color(0xFFC9D2CD);
  static const Color textPrimary = Color(0xFF1A1F1D);
  static const Color textSecondary = Color(0xFF5B655F);

  /// Sombras em camadas ("shadow-border"): 1px de anel + elevação sutil +
  /// profundidade ambiente — substitui bordas sólidas em cards/botões.
  static const Color shadowRing = Color(0x0F000000);
  static const Color shadowLift = Color(0x0D000000);
  static const Color shadowAmbient = Color(0x0A000000);

  /// Cores alternadas usadas para destacar visualmente grupos consecutivos
  /// de linhas com o mesmo numeroGuiaPrestador.
  static const List<Color> groupBackgrounds = [
    Color(0xFFFFFFFF),
    Color(0xFFF5F7F6),
  ];
}
