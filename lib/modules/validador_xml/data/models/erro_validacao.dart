import 'package:freezed_annotation/freezed_annotation.dart';

part 'erro_validacao.freezed.dart';

@freezed
abstract class ErroValidacao with _$ErroValidacao {
  const factory ErroValidacao({
    required String campo,
    required String mensagem,
  }) = _ErroValidacao;
}
