// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:material_ui/material_ui.dart';
import '../../../../globals/constants/app_colors.dart';
import '../../../../globals/constants/app_dimens.dart';
import '../../../../globals/constants/app_strings.dart';
import '../../data/models/guia_validada.dart';

class GradeGuias extends StatefulWidget {
  const GradeGuias({
    super.key,
    required this.linhas,
    required this.aoSelecionar,
  });

  final List<dynamic> linhas;
  final Future<void> Function(GuiaValidada) aoSelecionar;

  @override
  State<GradeGuias> createState() => _GradeGuiasState();
}

class _GradeGuiasState extends State<GradeGuias> {
  late final String _viewType;
  html.DivElement? _element;
  bool _dialogAberto = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'grade-guias-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final element = html.DivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block'
        ..style.overflow = 'visible'
        ..style.backgroundColor = 'transparent';
      _element = element;
      _renderTable(element);
      return element;
    });
  }

  @override
  void didUpdateWidget(covariant GradeGuias oldWidget) {
    super.didUpdateWidget(oldWidget);
    final html.DivElement? element = _element;
    if (element != null) {
      _renderTable(element);
      _syncInteractivity(element);
    }
  }

  void _renderTable(html.DivElement host) {
    final table = html.TableElement()
      ..style.width = '100%'
      ..style.tableLayout = 'fixed'
      ..style.borderCollapse = 'collapse'
      ..style.border = '1px solid ${_cssColor(AppColors.border)}'
      ..style.backgroundColor = 'transparent'
      ..style.color = _cssColor(AppColors.textPrimary)
      ..style.fontFamily = 'Roboto, "Helvetica Neue", Arial, sans-serif'
      ..style.fontSize = '15px';

    final columns = html.Element.tag('colgroup');
    for (final String width in ['52px', '25%', '75%']) {
      columns.append(
        html.Element.tag('col')..setAttribute('style', 'width:$width'),
      );
    }
    table.append(columns);

    final header = html.Element.tag('thead') as html.TableSectionElement;
    final headerRow = html.TableRowElement()..style.height = '38px';
    headerRow.append(_makeHeaderCell('', hidden: true));
    headerRow.append(_makeHeaderCell(AppStrings.rotuloGuia));
    headerRow.append(_makeHeaderCell(AppStrings.rotuloDetalhes));
    header.append(headerRow);
    table.append(header);

    final body = html.Element.tag('tbody') as html.TableSectionElement;
    for (final linha in widget.linhas) {
      body.append(_makeRow(linha));
    }
    table.append(body);

    host.children
      ..clear()
      ..add(table);
  }

  html.Element _makeHeaderCell(
    String text, {
    bool hidden = false,
  }) {
    final cell = html.Element.tag('th')
      ..setAttribute(
        'style',
        _cellStyle(
          fontSize: '13px',
          fontWeight: '700',
          color: AppColors.textMuted,
          selectable: false,
        ),
      );
    if (!hidden) {
      cell.append(
        html.SpanElement()
          ..text = text
          ..setAttribute('data-selectable-text', '')
          ..style.setProperty('user-select', 'text')
          ..style.setProperty('-webkit-user-select', 'text'),
      );
    }
    if (hidden) {
      cell.setAttribute('aria-hidden', 'true');
    } else {
      cell.setAttribute('scope', 'col');
    }
    return cell;
  }

  html.TableRowElement _makeRow(dynamic linha) {
    final guia = linha.guia;
    final row = html.TableRowElement()..style.height = '40px';

    row.append(_makeStatusCell(guia));
    row.append(
      _makeBodyCell(
        guia.numeroGuiaPrestador,
        fontWeight: '700',
      ),
    );
    row.append(_makeBodyCell(linha.detalhe));
    row.onMouseOver.listen((event) {
      final bool overSelectableText = _isSelectableTextTarget(event.target);
      row.style
        ..cursor = overSelectableText ? 'text' : 'pointer'
        ..backgroundColor = overSelectableText
            ? 'transparent'
            : _cssColor(AppColors.hoverLinha);
    });
    row.onMouseLeave.listen((_) {
      row.style
        ..cursor = 'pointer'
        ..backgroundColor = 'transparent';
    });
    row.onClick.listen((event) {
      if (_isSelectableTextTarget(event.target)) return;
      _selectGuide(guia);
    });

    return row;
  }

  html.Element _makeStatusCell(dynamic guia) {
    final cell = _makeBodyCell('')
      ..setAttribute(
        'style',
        _cellStyle(
          textAlign: 'center',
          color: AppColors.error,
          selectable: false,
        ),
      );
    final button = html.ButtonElement()
      ..type = 'button'
      ..setAttribute(
        'aria-label',
        '${AppStrings.rotuloGuia} ${guia.numeroGuiaPrestador}',
      )
      ..style.display = 'block'
      ..style.width = '${AppDimens.itemIcone}px'
      ..style.height = '${AppDimens.itemIcone}px'
      ..style.margin = '0 auto'
      ..style.padding = '0'
      ..style.border = '0'
      ..style.backgroundColor = 'transparent'
      ..style.color = _cssColor(AppColors.error)
      ..style.cursor = 'pointer';
    button.setInnerHtml(
      '''
      <svg aria-hidden="true" focusable="false" viewBox="0 0 24 24"
           width="${AppDimens.itemIcone}" height="${AppDimens.itemIcone}"
           style="display:block;margin:0 auto;fill:currentColor">
        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm5 13.59L15.59 17 12 13.41 8.41 17 7 15.59 10.59 12 7 8.41 8.41 7 12 10.59 15.59 7 17 8.41 13.41 12 17 15.59z"/>
      </svg>
      ''',
      treeSanitizer: html.NodeTreeSanitizer.trusted,
    );
    button.onClick.listen((event) {
      event.stopPropagation();
      _selectGuide(guia);
    });
    button.onFocus.listen((_) {
      button.style.outline = '2px solid ${_cssColor(AppColors.primary)}';
      button.style.outlineOffset = '2px';
    });
    button.onBlur.listen((_) => button.style.outline = 'none');
    cell.append(button);
    return cell;
  }

  html.Element _makeBodyCell(
    String text, {
    String fontWeight = '400',
  }) {
    final cell = html.Element.tag('td')
      ..setAttribute(
        'style',
        _cellStyle(
          fontSize: '15px',
          fontWeight: fontWeight,
          selectable: false,
        ),
      );
    if (text.isNotEmpty) {
      cell.append(
        html.SpanElement()
          ..text = text
          ..setAttribute('data-selectable-text', '')
          ..style.cursor = 'text'
          ..style.setProperty('user-select', 'text')
          ..style.setProperty('-webkit-user-select', 'text'),
      );
    }
    return cell;
  }

  static String _cellStyle({
    String? width,
    String fontSize = '15px',
    String fontWeight = '400',
    String textAlign = 'left',
    Color? color,
    bool selectable = true,
  }) {
    return [
      'box-sizing:border-box',
      'border:1px solid ${_cssColor(AppColors.border)}',
      if (width != null) 'width:$width',
      'padding:${AppDimens.itemPaddingV}px ${AppDimens.spaceMd}px',
      'vertical-align:middle',
      'text-align:$textAlign',
      'font-size:$fontSize',
      'font-weight:$fontWeight',
      'line-height:normal',
      'background-color:transparent',
      'user-select:${selectable ? 'text' : 'none'}',
      '-webkit-user-select:${selectable ? 'text' : 'none'}',
      if (color != null) 'color:${_cssColor(color)}',
    ].join(';');
  }

  void _selectGuide(dynamic guide) {
    if (guide is GuiaValidada && !_dialogAberto) {
      _abrirDetalhes(guide);
    }
  }

  bool _isSelectableTextTarget(html.EventTarget? target) {
    final html.Element? element;
    if (target is html.Element) {
      element = target;
    } else if (target is html.Node) {
      final html.Node? parent = target.parentNode;
      element = parent is html.Element ? parent : null;
    } else {
      element = null;
    }
    return element?.closest('[data-selectable-text]') != null;
  }

  Future<void> _abrirDetalhes(GuiaValidada guia) async {
    setState(() => _dialogAberto = true);
    final html.DivElement? element = _element;
    if (element != null) _syncInteractivity(element);
    try {
      await widget.aoSelecionar(guia);
    } finally {
      if (mounted) {
        setState(() => _dialogAberto = false);
        final html.DivElement? currentElement = _element;
        if (currentElement != null) _syncInteractivity(currentElement);
      }
    }
  }

  void _syncInteractivity(html.DivElement element) {
    if (_dialogAberto) {
      element
        ..style.pointerEvents = 'none'
        ..setAttribute('inert', '')
        ..setAttribute('aria-hidden', 'true')
        ..setAttribute('aria-disabled', 'true');
      return;
    }
    element
      ..style.pointerEvents = 'auto'
      ..removeAttribute('inert')
      ..removeAttribute('aria-hidden')
      ..removeAttribute('aria-disabled');
  }

  static String _cssColor(Color color) {
    final int value = color.value;
    final int alpha = value >> 24;
    final int red = (value >> 16) & 0xff;
    final int green = (value >> 8) & 0xff;
    final int blue = value & 0xff;
    if (alpha == 0xff) {
      return '#${value.toRadixString(16).substring(2).padLeft(6, '0')}';
    }
    return 'rgba($red, $green, $blue, ${(alpha / 255).toStringAsFixed(3)})';
  }

  @override
  Widget build(BuildContext context) {
    final double height = 38.0 + widget.linhas.length * 40.0;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
