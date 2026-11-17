import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
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

  final void Function(String nomeArquivo, Uint8List bytes) onArquivoSelecionado;

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
            child: CustomPaint(
              painter: _BordaTracejada(
                cor: _arrastandoArquivo ? AppColors.navy : AppColors.border,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                color: _arrastandoArquivo
                    ? AppColors.surfaceMuted
                    : Colors.transparent,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DropzoneView(
                        onCreated: (controller) => _controller = controller,
                        onHover: () => _definirArrasto(true),
                        onLeave: () => _definirArrasto(false),
                        onError: (erro) {
                          _definirArrasto(false);
                          _mostrarFalha(erro);
                        },
                        onDropFile: (arquivo) async {
                          _definirArrasto(false);
                          await _processarArquivo(arquivo);
                        },
                      ),
                    ),
                    Positioned.fill(
                      child: MouseRegion(
                        opaque: false,
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: _selecionarPorClique,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.spaceLg,
                            vertical: AppDimens.spaceXl,
                          ),
                          child: _arrastandoArquivo
                              ? const Icon(
                                  Icons.upload_outlined,
                                  size: AppDimens.dropZoneIconeArrasto,
                                  color: AppColors.navy,
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.description_outlined,
                                      size: AppDimens.dropZoneIcone,
                                      color: AppColors.textLight,
                                    ),
                                    SizedBox(height: AppDimens.spaceMd),
                                    TextoApp.corpo(
                                      AppStrings.dropZoneTexto,
                                      cor: AppColors.textLight,
                                      alinhamento: TextAlign.center,
                                      selecionavel: false,
                                    ),
                                  ],
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
      ),
    );
  }

  void _definirArrasto(bool valor) {
    if (_arrastandoArquivo == valor) return;
    setState(() => _arrastandoArquivo = valor);
  }

  Future<void> _selecionarPorClique() async {
    try {
      final arquivos = await _controller.pickFiles(
        multiple: false,
        mime: const ['text/xml', 'application/xml'],
      );
      if (arquivos.isEmpty) return;
      await _processarArquivo(arquivos.first);
    } on Exception catch (erro) {
      _mostrarFalha(erro);
    }
  }

  Future<void> _processarArquivo(DropzoneFileInterface arquivo) async {
    late final String nome;
    late final Uint8List bytes;
    try {
      nome = await _controller.getFilename(arquivo);

      if (!nome.toLowerCase().endsWith(_extensaoValida)) {
        _mostrarSnack(AppStrings.mensagemArquivoInvalidoExtensao);
        return;
      }

      bytes = await _controller.getFileData(arquivo);
    } on Exception catch (erro) {
      _mostrarFalha(erro);
      return;
    }

    widget.onArquivoSelecionado(nome, bytes);
  }

  void _mostrarFalha(Object? erro) {
    final String? detalhe = erro?.toString();
    _mostrarSnack(
      detalhe == null || detalhe.isEmpty
          ? AppStrings.mensagemFalhaCarregamentoArquivo
          : '${AppStrings.mensagemFalhaCarregamentoArquivo}: $detalhe',
    );
  }

  void _mostrarSnack(String mensagem) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: SelectableText(mensagem)));
  }
}

class _BordaTracejada extends CustomPainter {
  const _BordaTracejada({required this.cor});

  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint tinta = Paint()
      ..color = cor
      ..strokeWidth = AppDimens.dropZoneBorda
      ..style = PaintingStyle.stroke;
    final Path contorno = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final Path tracejado = Path();
    for (final ui.PathMetric metrica in contorno.computeMetrics()) {
      double distancia = 0;
      while (distancia < metrica.length) {
        final double fim = distancia + AppDimens.dropZoneTraco;
        tracejado.addPath(
          metrica.extractPath(distancia, fim.clamp(0, metrica.length)),
          Offset.zero,
        );
        distancia = fim + AppDimens.dropZoneVao;
      }
    }
    canvas.drawPath(tracejado, tinta);
  }

  @override
  bool shouldRepaint(covariant _BordaTracejada oldDelegate) =>
      oldDelegate.cor != cor;
}
