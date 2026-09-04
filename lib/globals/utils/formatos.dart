import '../constants/app_strings.dart';

String formatarTamanho(int? bytes) {
  if (bytes == null) return AppStrings.valorIndisponivel;
  if (bytes < 1024) return '$bytes B';
  final double kb = bytes / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  }
  final double mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
}

String formatarMoeda(String? valor) {
  final double? numero = double.tryParse((valor ?? '').trim());
  if (numero == null) return AppStrings.valorIndisponivel;

  final bool negativo = numero < 0;
  final double absoluto = numero.abs();
  final String inteira = absoluto.floor().toString();
  final int centavos =
      (absoluto * 100).round() - absoluto.floor() * 100;

  final StringBuffer inteiraAgrupada = StringBuffer();
  for (int i = 0; i < inteira.length; i++) {
    final int distanciaDoFim = inteira.length - i;
    if (i > 0 && distanciaDoFim % 3 == 0) inteiraAgrupada.write('.');
    inteiraAgrupada.write(inteira[i]);
  }

  final String sinal = negativo ? '-' : '';
  return 'R\$ $sinal$inteiraAgrupada,${centavos.toString().padLeft(2, '0')}';
}
