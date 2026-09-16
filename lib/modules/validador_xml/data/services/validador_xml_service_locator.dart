import 'package:get_it/get_it.dart';

import '../../../../globals/network/dio_client.dart';
import 'sul_america_backend_service.dart';

void configurarDependenciasValidadorXml(GetIt getIt) {
  if (!getIt.isRegistered<SulAmericaBackendService>()) {
    getIt.registerLazySingleton<SulAmericaBackendService>(
      () => SulAmericaBackendService(getIt<DioClient>()),
    );
  }
}
