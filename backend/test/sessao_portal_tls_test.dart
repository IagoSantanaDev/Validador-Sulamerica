import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:test/test.dart';
import 'package:validador_backend/modules/sulamerica/data/sessao_portal.dart';

/// Certificado falso com DER conhecido, para exercitar o pinning sem rede.
class _CertificadoFake implements X509Certificate {
  _CertificadoFake(this.der);

  @override
  final Uint8List der;

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
  Uint8List get sha1 => Uint8List.fromList(crypto.sha1.convert(der).bytes);
}

void main() {
  final Uint8List der = Uint8List.fromList(utf8.encode('certificado-teste'));
  final String fingerprintEsperado = crypto.sha256.convert(der).toString();

  group('SessaoPortal - pinning de certificado', () {
    test('aceita certificado com fingerprint correspondente', () {
      final sessao = SessaoPortal(
        fingerprintEsperado: fingerprintEsperado,
      );
      expect(
        sessao.validarCertificado(
          _CertificadoFake(der),
          SessaoPortal.hostPortal,
          443,
        ),
        isTrue,
      );
    });

    test('rejeita certificado com fingerprint divergente', () {
      final sessao = SessaoPortal(
        fingerprintEsperado:
            crypto.sha256.convert(utf8.encode('outro')).toString(),
      );
      expect(
        sessao.validarCertificado(
          _CertificadoFake(der),
          SessaoPortal.hostPortal,
          443,
        ),
        isFalse,
      );
    });

    test('rejeita host inesperado mesmo com fingerprint correto', () {
      final sessao = SessaoPortal(
        fingerprintEsperado: fingerprintEsperado,
      );
      expect(
        sessao.validarCertificado(_CertificadoFake(der), 'outro.host', 443),
        isFalse,
      );
    });

    test('rejeita certificado nulo com pinning configurado', () {
      final sessao = SessaoPortal(
        fingerprintEsperado: fingerprintEsperado,
      );
      expect(
        sessao.validarCertificado(null, SessaoPortal.hostPortal, 443),
        isFalse,
      );
    });

    test('sem pinning aceita certificado de CA valida do host do portal', () {
      // Sem fingerprint configurado nao ha pinning: a autoridade ja foi
      // validada pelo HttpClient, e o host precisa ser o do portal.
      final sessao = SessaoPortal();
      expect(
        sessao.validarCertificado(
          _CertificadoFake(der),
          SessaoPortal.hostPortal,
          443,
        ),
        isTrue,
      );
    });

    test('sem pinning rejeita host diferente', () {
      final sessao = SessaoPortal();
      expect(
        sessao.validarCertificado(_CertificadoFake(der), 'evil.example', 443),
        isFalse,
      );
    });
  });
}
