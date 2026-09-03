import 'package:get_it/get_it.dart';

import 'network/dio_client.dart';

final GetIt getIt = GetIt.instance;

/// Ponto único de registro das dependências globais (compartilhadas por
/// mais de um módulo). Cada módulo deve ter sua própria função de registro
/// para os próprios repositórios/controllers, chamada a partir daqui.
void configurarDependenciasGlobais({required String baseUrlPadrao}) {
  if (!getIt.isRegistered<DioClient>()) {
    getIt.registerLazySingleton<DioClient>(
      () => DioClient(baseUrl: baseUrlPadrao),
    );
  }
}
