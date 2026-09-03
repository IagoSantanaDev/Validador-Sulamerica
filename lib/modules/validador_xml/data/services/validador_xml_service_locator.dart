import 'package:get_it/get_it.dart';

import '../../../../globals/network/dio_client.dart';
import 'sul_america_backend_service.dart';

/// Registro de dependências específicas do módulo validador_xml.
///
/// Fica fora de lib/globals/service_locator.dart de propósito: o
/// container global não deve conhecer regra de negócio de um módulo
/// específico. Chame esta função depois de configurarDependenciasGlobais().
///
/// O [SulAmericaBackendService] substitui as chamadas diretas ao portal
/// (antigo SulAmericaService): todo acesso à SulAmérica passa pelos
/// endpoints do backend intermediário (`AppConfig.baseUrlApi`).
void configurarDependenciasValidadorXml(GetIt getIt) {
  if (!getIt.isRegistered<SulAmericaBackendService>()) {
    getIt.registerLazySingleton<SulAmericaBackendService>(
      () => SulAmericaBackendService(getIt<DioClient>()),
    );
  }
}