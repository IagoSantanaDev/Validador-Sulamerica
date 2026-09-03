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
  bool _emHover = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: AppDimens.dropZoneMaxWidth,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppDimens.dropZoneLarguraMax),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceLg,
              vertical: AppDimens.spaceXl,
            ),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              border: Border.all(
                color: _emHover ? AppColors.primary : AppColors.border,
                width: AppDimens.dropZoneBorda,
              ),
            ),
            child: Stack(
              children: [
                DropzoneView(
                  onCreated: (controller) => _controller = controller,
                  onHover: () => setState(() => _emHover = true),
                  onLeave: () => setState(() => _emHover = false),
                  onDropFile: _processarArquivo,
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      onTap: _selecionarPorClique,
                      child: Opacity(
                        opacity: _emHover ? 1 : AppDimens.dropZoneOpacidade,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppDimens.spaceLg,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cloud_upload,
                                size: AppDimens.dropZoneIcone,
                                color: AppColors.textLight,
                              ),
                              SizedBox(height: AppDimens.spaceMd),
                              TextoApp.corpo(
                                AppStrings.dropZoneTextoLinha1,
                                cor: AppColors.textLight,
                                alinhamento: TextAlign.center,
                              ),
                              TextoApp.corpo(
                                AppStrings.dropZoneTextoLinha2,
                                cor: AppColors.textLight,
                                alinhamento: TextAlign.center,
                              ),
                            ],
                          ),
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
    );
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
        ?.showSnackBar(SnackBar(content: Text(mensagem)));
  }
}