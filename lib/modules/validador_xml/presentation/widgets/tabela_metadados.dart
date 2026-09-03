import 'package:flutter/material.dart';

import '../../../../globals/constants/app_colors.dart';
import '../../../../globals/constants/app_dimens.dart';
import '../../../../globals/constants/app_strings.dart';
import '../../../../globals/utils/formatos.dart';
import '../../../../globals/widgets/rotulo_valor.dart';
import '../../data/models/informacoes_lote.dart';

class TabelaMetadados extends StatelessWidget {
  const TabelaMetadados({
    super.key,
    required this.nomeArquivo,
    required this.tamanhoArquivoBytes,
    required this.informacoes,
    required this.hashMd5,
  });

  final String? nomeArquivo;
  final int? tamanhoArquivoBytes;
  final InformacoesLote informacoes;
  final String? hashMd5;

  @override
  Widget build(BuildContext context) {
    final List<(String, String)> linhas = [
      (AppStrings.metadadoNome, nomeArquivo ?? AppStrings.valorIndisponivel),
      (AppStrings.metadadoTamanho, formatarTamanho(tamanhoArquivoBytes)),
      (AppStrings.metadadoVersao, informacoes.versao ?? AppStrings.valorIndisponivel),
      (
        AppStrings.metadadoTipoTransacao,
        informacoes.tipoTransacao ?? AppStrings.valorIndisponivel,
      ),
      (AppStrings.metadadoHash, hashMd5 ?? AppStrings.valorIndisponivel),
      (
        AppStrings.metadadoPrestador,
        informacoes.prestadorCnpjCpf ?? AppStrings.valorIndisponivel,
      ),
      (
        AppStrings.metadadoOperadora,
        informacoes.operadoraRegistroANS ?? AppStrings.valorIndisponivel,
      ),
      (
        AppStrings.metadadoNumeroLote,
        informacoes.numeroLote ?? AppStrings.valorIndisponivel,
      ),
      (AppStrings.metadadoTipoGuia, informacoes.tipoGuia ?? AppStrings.valorIndisponivel),
      (
        AppStrings.metadadoQtdGuias,
        informacoes.qtdGuias?.toString() ?? AppStrings.valorIndisponivel,
      ),
      (
        AppStrings.metadadoValorTotalInformado,
        informacoes.valorTotalInformado ?? AppStrings.valorIndisponivel,
      ),
    ];

    return Column(
      children: [
        for (int i = 0; i < linhas.length; i++)
          Container(
            color: i.isOdd ? AppColors.surfaceMuted : null,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: 10,
            ),
            child: RotuloValor(rotulo: linhas[i].$1, valor: linhas[i].$2),
          ),
      ],
    );
  }
}