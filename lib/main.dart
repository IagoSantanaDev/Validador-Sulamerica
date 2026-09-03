import 'package:flutter/material.dart';

import 'globals/constants/app_config.dart';
import 'globals/constants/app_strings.dart';
import 'globals/service_locator.dart';
import 'globals/themes/app_theme.dart';
import 'modules/validador_xml/data/services/validador_xml_service_locator.dart';
import 'modules/validador_xml/presentation/pages/validador_page.dart';

void main() {
  configurarDependenciasGlobais(baseUrlPadrao: AppConfig.baseUrlApi);
  configurarDependenciasValidadorXml(getIt);
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