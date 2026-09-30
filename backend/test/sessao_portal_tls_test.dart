import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:validador_backend/modules/sulamerica/data/sessao_portal.dart';

/// Certificado falso, para exercitar a checagem de host sem rede.
class _CertificadoFake implements X509Certificate {
  @override
  final Uint8List der = Uint8List.fromList(<int>[1, 2, 3]);

  @override
  String get pem =>
      '-----BEGIN CERTIFICATE-----\n--\n-----END CERTIFICATE-----';

  @override
  String get subject => 'CN=${SessaoPortal.hostPortal}';

  @override
  String get issuer => 'CN=Emissor Teste';

  @override
  DateTime get startValidity => DateTime(2024);

  @override
  DateTime get endValidity => DateTime(2030);

  @override
  Uint8List get sha1 => Uint8List.fromList(<int>[1, 2, 3]);
}

void main() {
  final _CertificadoFake certificado = _CertificadoFake();

  group('SessaoPortal - TLS', () {
    test('aceita o host do portal', () {
      // A cadeia e o hostname ja foram validados pelo HttpClient antes deste
      // callback; aqui resta apenas confirmar o host esperado.
      final SessaoPortal sessao = SessaoPortal();
      expect(
        sessao.validarCertificado(certificado, SessaoPortal.hostPortal, 443),
        isTrue,
      );
    });

    test('rejeita host inesperado', () {
      final SessaoPortal sessao = SessaoPortal();
      expect(
        sessao.validarCertificado(certificado, 'evil.example', 443),
        isFalse,
      );
    });

    test('sessao nao depende de configuracao de TLS para ser criada', () {
      // Sem pinning nao ha variavel de ambiente envolvida: a sessao nasce
      // igual em qualquer ambiente. Um valor de fingerprint preenchido por
      // engano derrubava toda conexao com o portal.
      final SessaoPortal sessao = SessaoPortal();
      expect(sessao.autenticada, isFalse);
    });
  });
}