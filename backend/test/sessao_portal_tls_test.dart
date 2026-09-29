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
      // Passa '' explicitamente para nao depender do ambiente de quem roda.
      final sessao = SessaoPortal(fingerprintEsperado: '');
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
      final sessao = SessaoPortal(fingerprintEsperado: '');
      expect(
        sessao.validarCertificado(_CertificadoFake(der), 'evil.example', 443),
        isFalse,
      );
    });
  });

  group('SessaoPortal - normalizacao do fingerprint', () {
    test('fingerprint vazia vale como ausente e cai na validacao de CA', () {
      // Sem normalizacao, '' e nao-nulo e entraria no ramo de pinning,
      // comparando o SHA256 real contra '' e reprovando toda conexao.
      final sessao = SessaoPortal(fingerprintEsperado: '');
      expect(
        sessao.validarCertificado(
          _CertificadoFake(der),
          SessaoPortal.hostPortal,
          443,
        ),
        isTrue,
      );
    });

    test('fingerprint so com espacos vale como ausente', () {
      final sessao = SessaoPortal(fingerprintEsperado: '   ');
      expect(
        sessao.validarCertificado(
          _CertificadoFake(der),
          SessaoPortal.hostPortal,
          443,
        ),
        isTrue,
      );
    });

    test('fingerprint vazia nao afrouxa a checagem de host', () {
      final sessao = SessaoPortal(fingerprintEsperado: '');
      expect(
        sessao.validarCertificado(_CertificadoFake(der), 'evil.example', 443),
        isFalse,
      );
    });

    test('fingerprint malformada falha o boot com ArgumentError', () {
      expect(
        () => SessaoPortal(fingerprintEsperado: 'aabbcc'),
        throwsArgumentError,
      );
    });

    test('fingerprint com tamanho errado falha o boot', () {
      expect(
        () => SessaoPortal(fingerprintEsperado: '${fingerprintEsperado}ab'),
        throwsArgumentError,
      );
    });

    test('fingerprint com caractere nao hexadecimal falha o boot', () {
      expect(
        () => SessaoPortal(
          fingerprintEsperado: 'z${fingerprintEsperado.substring(1)}',
        ),
        throwsArgumentError,
      );
    });

    test('mensagem de erro nao inclui o valor do fingerprint', () {
      Object? erro;
      try {
        SessaoPortal(fingerprintEsperado: 'segredo-malformado');
      } catch (e) {
        erro = e;
      }
      expect(erro, isArgumentError);
      expect(erro.toString(), contains('PORTAL_CERT_FINGERPRINT_SHA256'));
      expect(erro.toString(), isNot(contains('segredo-malformado')));
    });

    test('fingerprint valida em caixa alta continua funcionando', () {
      // O openssl imprime em caixa alta; normalizar para minusculo evita
      // derrubar o boot por um fingerprint valido.
      final sessao = SessaoPortal(
        fingerprintEsperado: fingerprintEsperado.toUpperCase(),
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

    test('fingerprint valida entre espaco nas bordas funciona', () {
      final sessao = SessaoPortal(
        fingerprintEsperado: '  $fingerprintEsperado  ',
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
  });
}
