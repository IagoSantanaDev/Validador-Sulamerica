import 'package:get_it/get_it.dart';

import 'sul_america_campos.dart';
import 'sul_america_service.dart';

/// Registro de dependências específicas do módulo validador_xml.
///
/// Fica fora de lib/globals/service_locator.dart de propósito: o
/// container global não deve conhecer regra de negócio de um módulo
/// específico. Chame esta função depois de configurarDependenciasGlobais().
void configurarDependenciasValidadorXml(GetIt getIt) {
  if (!getIt.isRegistered<SulAmericaService>()) {
    getIt.registerLazySingleton<SulAmericaService>(
      () => SulAmericaService(
        camposLogin: SulAmericaCampos.login,
        camposConsulta: SulAmericaCampos.consulta,
      ),
    );
  }
}
