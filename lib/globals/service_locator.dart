import 'package:get_it/get_it.dart';

import 'network/dio_client.dart';

final GetIt getIt = GetIt.instance;

void configurarDependenciasGlobais({required String baseUrlPadrao}) {
  if (!getIt.isRegistered<DioClient>()) {
    getIt.registerLazySingleton<DioClient>(
      () => DioClient(baseUrl: baseUrlPadrao),
    );
  }
}