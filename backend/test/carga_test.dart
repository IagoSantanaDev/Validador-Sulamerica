import 'dart:convert';

import 'package:test/test.dart';
import '../tool/simular_carga.dart';

void main() {
  for (final bool dividirIdentificadores in [false, true]) {
    test(
      '12 clientes com 300 consultas concluem '
      '(${dividirIdentificadores ? 'dois identificadores' : 'um identificador'})',
      () async {
        final Map<String, Object> report = await executarCarga(
          dividirIdentificadores: dividirIdentificadores,
          latencia: const Duration(milliseconds: 2),
        );

        expect(report['clientes'], 12);
        expect(report['itensPorCliente'], 300);
        expect(report['concluidos'], 12);
        expect(report['rejeicoes429'], 0);
        expect((report['duracaoMs'] as Map)['p50'], greaterThanOrEqualTo(0));
        expect((report['duracaoMs'] as Map)['p95'], greaterThanOrEqualTo(0));
        expect(report['rssMb'], greaterThan(0));
        expect(jsonEncode(report), isNotEmpty);
      },
    );
  }
}
