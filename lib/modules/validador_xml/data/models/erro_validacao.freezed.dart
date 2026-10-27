// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'erro_validacao.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ErroValidacao {
  String get campo;
  String get mensagem;

  /// Create a copy of ErroValidacao
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ErroValidacaoCopyWith<ErroValidacao> get copyWith =>
      _$ErroValidacaoCopyWithImpl<ErroValidacao>(
          this as ErroValidacao, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ErroValidacao &&
            (identical(other.campo, campo) || other.campo == campo) &&
            (identical(other.mensagem, mensagem) ||
                other.mensagem == mensagem));
  }

  @override
  int get hashCode => Object.hash(runtimeType, campo, mensagem);

  @override
  String toString() {
    return 'ErroValidacao(campo: $campo, mensagem: $mensagem)';
  }
}

/// @nodoc
abstract mixin class $ErroValidacaoCopyWith<$Res> {
  factory $ErroValidacaoCopyWith(
          ErroValidacao value, $Res Function(ErroValidacao) _then) =
      _$ErroValidacaoCopyWithImpl;
  @useResult
  $Res call({String campo, String mensagem});
}

/// @nodoc
class _$ErroValidacaoCopyWithImpl<$Res>
    implements $ErroValidacaoCopyWith<$Res> {
  _$ErroValidacaoCopyWithImpl(this._self, this._then);

  final ErroValidacao _self;
  final $Res Function(ErroValidacao) _then;

  /// Create a copy of ErroValidacao
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? campo = null,
    Object? mensagem = null,
  }) {
    return _then(_self.copyWith(
      campo: null == campo
          ? _self.campo
          : campo // ignore: cast_nullable_to_non_nullable
              as String,
      mensagem: null == mensagem
          ? _self.mensagem
          : mensagem // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [ErroValidacao].
extension ErroValidacaoPatterns on ErroValidacao {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_ErroValidacao value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ErroValidacao() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_ErroValidacao value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ErroValidacao():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_ErroValidacao value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ErroValidacao() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(String campo, String mensagem)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ErroValidacao() when $default != null:
        return $default(_that.campo, _that.mensagem);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(String campo, String mensagem) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ErroValidacao():
        return $default(_that.campo, _that.mensagem);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(String campo, String mensagem)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ErroValidacao() when $default != null:
        return $default(_that.campo, _that.mensagem);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ErroValidacao implements ErroValidacao {
  const _ErroValidacao({required this.campo, required this.mensagem});

  @override
  final String campo;
  @override
  final String mensagem;

  /// Create a copy of ErroValidacao
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ErroValidacaoCopyWith<_ErroValidacao> get copyWith =>
      __$ErroValidacaoCopyWithImpl<_ErroValidacao>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ErroValidacao &&
            (identical(other.campo, campo) || other.campo == campo) &&
            (identical(other.mensagem, mensagem) ||
                other.mensagem == mensagem));
  }

  @override
  int get hashCode => Object.hash(runtimeType, campo, mensagem);

  @override
  String toString() {
    return 'ErroValidacao(campo: $campo, mensagem: $mensagem)';
  }
}

/// @nodoc
abstract mixin class _$ErroValidacaoCopyWith<$Res>
    implements $ErroValidacaoCopyWith<$Res> {
  factory _$ErroValidacaoCopyWith(
          _ErroValidacao value, $Res Function(_ErroValidacao) _then) =
      __$ErroValidacaoCopyWithImpl;
  @override
  @useResult
  $Res call({String campo, String mensagem});
}

/// @nodoc
class __$ErroValidacaoCopyWithImpl<$Res>
    implements _$ErroValidacaoCopyWith<$Res> {
  __$ErroValidacaoCopyWithImpl(this._self, this._then);

  final _ErroValidacao _self;
  final $Res Function(_ErroValidacao) _then;

  /// Create a copy of ErroValidacao
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? campo = null,
    Object? mensagem = null,
  }) {
    return _then(_ErroValidacao(
      campo: null == campo
          ? _self.campo
          : campo // ignore: cast_nullable_to_non_nullable
              as String,
      mensagem: null == mensagem
          ? _self.mensagem
          : mensagem // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
