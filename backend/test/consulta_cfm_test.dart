import 'package:test/test.dart';

import 'package:validador_backend/consulta_cfm.dart';

void main() {
  group('Contrato ConsultaCfm', () {
    test('permite implementar consulta assíncrona por CRM e UF', () async {
      const ResultadoConsultaCfm esperado = ResultadoConsultaCfm(
        estado: EstadoConsultaCfm.conformeDados,
        crm: '12345',
        uf: 'SP',
        nome: 'PROFISSIONAL FICTICIO',
        situacao: 'ATIVO',
        tipoInscricao: 'PRINCIPAL',
        dataAtualizacao: '2026-01-01',
        especialidade: 'CLINICA MEDICA',
      );
      final _ConsultaCfmFake consulta = _ConsultaCfmFake(esperado);

      final ResultadoConsultaCfm resultado = await consulta.consultar(
        crm: '12345',
        uf: 'SP',
      );

      expect(consulta.crmConsultado, '12345');
      expect(consulta.ufConsultada, 'SP');
      expect(resultado, same(esperado));
      expect(resultado.estado, EstadoConsultaCfm.conformeDados);
      expect(resultado.nome, 'PROFISSIONAL FICTICIO');
      expect(resultado.especialidade, 'CLINICA MEDICA');
    });

    test('mantém não encontrado distinto de falha técnica', () {
      const ResultadoConsultaCfm naoEncontrado = ResultadoConsultaCfm(
        estado: EstadoConsultaCfm.naoEncontrado,
      );
      const ResultadoConsultaCfm falha = ResultadoConsultaCfm(
        estado: EstadoConsultaCfm.falhaConsulta,
      );

      expect(naoEncontrado.estado, isNot(falha.estado));
      expect(naoEncontrado.crm, isNull);
      expect(falha.nome, isNull);
    });
  });
}

final class _ConsultaCfmFake implements ConsultaCfm {
  _ConsultaCfmFake(this.resultado);

  final ResultadoConsultaCfm resultado;
  String? crmConsultado;
  String? ufConsultada;

  @override
  Future<ResultadoConsultaCfm> consultar({
    required String crm,
    required String uf,
  }) async {
    crmConsultado = crm;
    ufConsultada = uf;
    return resultado;
  }
}
