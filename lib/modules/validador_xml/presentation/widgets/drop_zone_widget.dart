import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';

import '../../../../globals/constants/app_colors.dart';
import '../../../../globals/constants/app_dimens.dart';
import '../../../../globals/constants/app_strings.dart';
import '../../../../globals/themes/app_theme.dart';

/// Área de seleção de arquivo por clique ou arraste, restrita a .xml.
///
/// Visual de "área hero" discreta: superfície clara com contorno tracejado
/// (affordance de soltar arquivo), ícone em chip arredondado e botão de
/// ação discreto (text/outline). Sombra em camadas no lugar de borda sólida
/// (skill make-interfaces-feel-better).
class DropZoneWidget extends StatefulWidget {
  const DropZoneWidget({
    super.key,
    required this.onArquivoSelecionado,
    required this.onErroSelecao,
    this.nomeArquivoAtual,
    this.tamanhoArquivoBytes,
  });

  final void Function(String nomeArquivo, Uint8List bytes)
      onArquivoSelecionado;
  final void Function(String mensagem) onErroSelecao;
  final String? nomeArquivoAtual;
  final int? tamanhoArquivoBytes;

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

    return Semantics(
      label: temArquivo
          ? '${AppStrings.dropZoneArquivoSelecionado}: '
              '${widget.nomeArquivoAtual}'
          : '${AppStrings.dropZoneTituloArrastar}. '
              '${AppStrings.dropZoneAcaoSelecionar}.',
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: AppDimens.dropZoneHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _emHover ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          boxShadow: _emHover
              ? AppTheme.sombraDeSurfaceElevada()
              : AppTheme.sombraDeSurface(),
          border: Border.all(
            color: _emHover ? AppColors.primary : AppColors.borderStrong,
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
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
                    borderRadius:
                        BorderRadius.circular(AppDimens.radiusLg),
                    onTap: _selecionarPorClique,
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.spaceLg),
                      child: _buildConteudo(context, temArquivo),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConteudo(BuildContext context, bool temArquivo) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animacao) => FadeTransition(
            opacity: animacao,
            child: ScaleTransition(scale: animacao, child: child),
          ),
          child: Container(
            key: ValueKey<bool>(temArquivo),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _emHover && !temArquivo
                  ? AppColors.surface
                  : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: Icon(
              temArquivo ? Icons.description_outlined : Icons.upload_file,
              size: 28,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        if (temArquivo) ...[
          Text(
            widget.nomeArquivoAtual!,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            _formatarTamanho(widget.tamanhoArquivoBytes),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppDimens.spaceMd),
          OutlinedButton.icon(
            onPressed: _selecionarPorClique,
            icon: const Icon(Icons.sync_alt, size: 18),
            label: const Text(AppStrings.botaoTrocarArquivo),
          ),
        ] else ...[
          Text(
            AppStrings.dropZoneTituloArrastar,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            AppStrings.dropZoneAcaoSelecionar,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.spaceMd),
          TextButton.icon(
            onPressed: _selecionarPorClique,
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text(AppStrings.botaoSelecionarArquivo),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            AppStrings.extensaoAceita,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  String _formatarTamanho(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    final double kb = bytes / 1024;
    return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
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