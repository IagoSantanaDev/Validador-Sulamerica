import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';

import '../../../../globals/constants/app_colors.dart';
import '../../../../globals/constants/app_dimens.dart';
import '../../../../globals/constants/app_strings.dart';

/// Área de seleção de arquivo por clique ou arraste, restrita a .xml.
/// Encapsula toda a integração com o pacote flutter_dropzone (Flutter Web).
class DropZoneWidget extends StatefulWidget {
  const DropZoneWidget({
    super.key,
    required this.onArquivoSelecionado,
    required this.onErroSelecao,
    this.nomeArquivoAtual,
  });

  final void Function(String nomeArquivo, Uint8List bytes)
      onArquivoSelecionado;
  final void Function(String mensagem) onErroSelecao;
  final String? nomeArquivoAtual;

  @override
  State<DropZoneWidget> createState() => _DropZoneWidgetState();
}

class _DropZoneWidgetState extends State<DropZoneWidget> {
  static const String _extensaoValida = '.xml';

  late final DropzoneViewController _controller;
  bool _emHover = false;

  @override
  Widget build(BuildContext context) {
    final bool temArquivo = widget.nomeArquivoAtual != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      child: SizedBox(
        height: AppDimens.dropZoneHeight,
        width: double.infinity,
        child: Stack(
          children: [
            _buildFundo(),
            DropzoneView(
              onCreated: (controller) => _controller = controller,
              onHover: () => setState(() => _emHover = true),
              onLeave: () => setState(() => _emHover = false),
              onDropFile: _processarArquivo,
            ),
            _buildConteudo(context, temArquivo),
          ],
        ),
      ),
    );
  }

  Widget _buildFundo() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: _emHover ? AppColors.successBackground : AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(
          color: _emHover ? AppColors.primary : AppColors.border,
          width: _emHover ? 2 : 1,
        ),
      ),
    );
  }

  Widget _buildConteudo(BuildContext context, bool temArquivo) {
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          onTap: _selecionarPorClique,
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  temArquivo ? Icons.description : Icons.upload_file,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(height: AppDimens.spaceMd),
                Text(
                  temArquivo
                      ? widget.nomeArquivoAtual!
                      : AppStrings.instrucaoDropZone,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimens.spaceXs),
                Text(
                  AppStrings.extensaoAceita,
                  style: Theme.of(context).textTheme.bodyMedium,
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
      widget.onErroSelecao(AppStrings.mensagemArquivoInvalidoExtensao);
      return;
    }

    final Uint8List bytes = await _controller.getFileData(arquivo);
    widget.onArquivoSelecionado(nome, bytes);
  }
}
