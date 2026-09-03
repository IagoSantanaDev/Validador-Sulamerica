import 'package:flutter/material.dart';

/// Paleta de cores centralizada do app. Evita cores "mágicas" espalhadas
/// pela UI (ver regra "Sem magic numbers" do padrão do projeto).
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF0A5C36);
  static const Color background = Color(0xFFF5F7F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);
  static const Color successBackground = Color(0xFFEAF7ED);
  static const Color border = Color(0xFFE0E4E2);
  static const Color textPrimary = Color(0xFF1A1F1D);
  static const Color textSecondary = Color(0xFF5B655F);

  /// Cores alternadas usadas para destacar visualmente grupos consecutivos
  /// de linhas com o mesmo numeroGuiaPrestador.
  static const List<Color> groupBackgrounds = [
    Color(0xFFFFFFFF),
    Color(0xFFF1F4F2),
  ];
}
