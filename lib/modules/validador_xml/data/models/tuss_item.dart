import 'package:freezed_annotation/freezed_annotation.dart';

part 'tuss_item.freezed.dart';

@freezed
abstract class TussItem with _$TussItem {
  const factory TussItem({
    required String id,
    required String nome,
    required String tabela,
    String? inicioVigencia,
    String? fimVigencia,
  }) = _TussItem;
}
