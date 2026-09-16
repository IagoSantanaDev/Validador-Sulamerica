import 'package:test/test.dart';
import 'package:validador_backend/elegibilidade_parser.dart';

const String _htmlSimplificadoSim = '''
<html><head><title>Elegibilidade - Resultado | SulAmerica</title></head>
<body>
<div class="box-padrao"> <div class="box-padrao-int" style="border-style:none!important;">
<div class="tit big">Validação de Elegibilidade</div>
<div class="linha"> <div> <strong>Carteira do beneficiário: </strong>
<span>582 01824 0043 8430 0010</span> </div> </div>
<div class="box-indicador-elegibilidade"> <div class="linha"> <div>
<strong>Elegível:&nbsp;</strong><span class="atencao">SIM</span> </div>
<div></div> </div> </div>
<div style="border: solid 2px #191970; color: #ffffff!important;">
</div></div></div>
</body></html>
''';

const String _htmlRotuloNao = '''
<div class="box-indicador-elegibilidade"> <div class="linha"> <div>
<strong>Elegível:</strong><span class="outro-uso">NÃO</span> </div>
</div> </div>
''';

const String _htmlSemResultado = '''
<html><head><title>Elegibilidade - Identificação | SulAmerica</title></head>
<body><div class="box-padrao"> <div class="tit big">Validação de Elegibilidade</div>
<div class="linha" id="box-validacao-beneficiario"> <div> <label class="cod">
Digite o número do beneficiário</label> </div> </div> </div></body></html>
''';

void main() {
  group('extrairRotuloElegibilidade', () {
    test('retorna SIM no HTML real da página de resultado', () {
      expect(extrairRotuloElegibilidade(_htmlSimplificadoSim), 'SIM');
    });

    test('retorna NÃO quando o rótulo é NÃO', () {
      expect(extrairRotuloElegibilidade(_htmlRotuloNao), 'NÃO');
    });

    test('retorna null quando não há bloco de resultado', () {
      expect(extrairRotuloElegibilidade(_htmlSemResultado), isNull);
    });
  });

  group('extrairElegivel', () {
    test('interpreta SIM como true', () {
      expect(extrairElegivel(_htmlSimplificadoSim), isTrue);
    });

    test('interpreta NÃO como false', () {
      expect(extrairElegivel(_htmlRotuloNao), isFalse);
    });

    test('retorna null quando não há resultado', () {
      expect(extrairElegivel(_htmlSemResultado), isNull);
    });

    test('é insensível a maiúsculas/minúsculas e espaços', () {
      const String html = '''
      <div class="box-indicador-elegibilidade">
        <strong>Elegível:&nbsp;</strong><span>   sim   </span>
      </div>
      ''';
      expect(extrairElegivel(html), isTrue);
    });
  });
}
