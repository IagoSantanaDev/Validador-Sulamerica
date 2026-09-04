import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';

import '../../../../globals/constants/app_colors.dart';
import '../../../../globals/constants/app_dimens.dart';
import '../../../../globals/constants/app_strings.dart';
import '../../../../globals/widgets/textos.dart';

class DropZoneSite extends StatefulWidget {
  const DropZoneSite({
    super.key,
    required this.onArquivoSelecionado,
  });

  final void Function(String nomeArquivo, Uint8List bytes)
      onArquivoSelecionado;

  @override
  State<DropZoneSite> createState() => _DropZoneSiteState();
}

class _DropZoneSiteState extends State<DropZoneSite> {
  static const String _extensaoValida = '.xml';

  late final DropzoneViewController _controller;
  bool _arrastandoArquivo = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: AppDimens.dropZoneMaxWidth,
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppDimens.dropZoneLarguraMax),
          child: SizedBox(
            height: AppDimens.dropZoneAltura,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                color: _arrastandoArquivo
                    ? AppColors.track
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                border: Border.all(
                  color: AppColors.border,
                  width: AppDimens.dropZoneBorda,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DropzoneView(
                      onCreated: (controller) => _controller = controller,
                      onHover: () => _definirArrasto(true),
                      onLeave: () => _definirArrasto(false),
                      onDropFile: (arquivo) {
                        _definirArrasto(false);
                        _processarArquivo(arquivo);
                      },
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceLg,
                        vertical: AppDimens.spaceXl,
                      ),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _selecionarPorClique,
                          child: _arrastandoArquivo
                              ? const Icon(
                                  Icons.upload_file,
                                  size: AppDimens.dropZoneIconeArrasto,
                                  color: AppColors.textMuted,
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.cloud_upload,
                                      size: AppDimens.dropZoneIcone,
                                      color: AppColors.textLight,
                                    ),
                                    SizedBox(height: AppDimens.spaceMd),
                                    TextoApp.corpo(
                                      AppStrings.dropZoneTexto,
                                      cor: AppColors.textLight,
                                      alinhamento: TextAlign.center,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _definirArrasto(bool valor) {
    if (_arrastandoArquivo == valor) return;
    setState(() => _arrastandoArquivo = valor);
  }

  Future<void> _selecionarPorClique() async {
    final List<dynamic> arquivos = await _controller.pickFiles(
      multiple: false,
      mime: const ['text/xml', 'application/xml'],
    );
    if (arquivos.isEmpty) return;
    await _processarArquivo(arquivos.first);
  }

  Future<void> _processarArquivo(dynamic arquivo) async {
    final String nome = await _controller.getFilename(arquivo);

    if (!nome.toLowerCase().endsWith(_extensaoValida)) {
      _mostrarSnack(AppStrings.mensagemArquivoInvalidoExtensao);
      return;
    }

    final Uint8List bytes = await _controller.getFileData(arquivo);
    widget.onArquivoSelecionado(nome, bytes);
  }

  void _mostrarSnack(String mensagem) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: SelectableText(mensagem)));
  }
}