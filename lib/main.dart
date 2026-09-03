import 'package:flutter/material.dart';

import 'globals/constants/app_strings.dart';
import 'globals/themes/app_theme.dart';
import 'modules/validador_xml/presentation/pages/validador_page.dart';

void main() {
  runApp(const ValidadorApp());
}

class ValidadorApp extends StatelessWidget {
  const ValidadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.tituloApp,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const ValidadorPage(),
    );
  }
}
