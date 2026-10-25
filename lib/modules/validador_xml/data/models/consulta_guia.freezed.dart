// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'consulta_guia.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ConsultaGuia {
  bool get sucesso;
  String get descricao;
  TipoConsultaGuia get tipo;

  /// Create a copy of ConsultaGuia
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ConsultaGuiaCopyWith<ConsultaGuia> get copyWith =>
      _$ConsultaGuiaCopyWithImpl<ConsultaGuia>(
          this as ConsultaGuia, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ConsultaGuia &&
            (identical(other.sucesso, sucesso) || other.sucesso == sucesso) &&
            (identical(other.descricao, descricao) ||
                other.descricao == descricao) &&
            (identical(other.tipo, tipo) || other.tipo == tipo));
  }

  @override
  int get hashCode => Object.hash(runtimeType, sucesso, descricao, tipo);

  @override
  String toString() {
    return 'ConsultaGuia(sucesso: $sucesso, descricao: $descricao, tipo: $tipo)';
  }
}

/// @nodoc
abstract mixin class $ConsultaGuiaCopyWith<$Res> {
  factory $ConsultaGuiaCopyWith(
          ConsultaGuia value, $Res Function(ConsultaGuia) _then) =
      _$ConsultaGuiaCopyWithImpl;
  @useResult
  $Res call({bool sucesso, String descricao, TipoConsultaGuia tipo});
}

/// @nodoc
class _$ConsultaGuiaCopyWithImpl<$Res> implements $ConsultaGuiaCopyWith<$Res> {
  _$ConsultaGuiaCopyWithImpl(this._self, this._then);

  final ConsultaGuia _self;
  final $Res Function(ConsultaGuia) _then;

  /// Create a copy of ConsultaGuia
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sucesso = null,
    Object? descricao = null,
    Object? tipo = null,
  }) {
    return _then(_self.copyWith(
      sucesso: null == sucesso
          ? _self.sucesso
          : sucesso // ignore: cast_nullable_to_non_nullable
              as bool,
      descricao: null == descricao
          ? _self.descricao
          : descricao // ignore: cast_nullable_to_non_nullable
              as String,
      tipo: null == tipo
          ? _self.tipo
          : tipo // ignore: cast_nullable_to_non_nullable
              as TipoConsultaGuia,
    ));
  }
}

/// Adds pattern-matching-related methods to [ConsultaGuia].
extension ConsultaGuiaPatterns on ConsultaGuia {
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
    TResult Function(_ConsultaGuia value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ConsultaGuia() when $default != null:
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
    TResult Function(_ConsultaGuia value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ConsultaGuia():
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
    TResult? Function(_ConsultaGuia value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ConsultaGuia() when $default != null:
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
    TResult Function(bool sucesso, String descricao, TipoConsultaGuia tipo)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ConsultaGuia() when $default != null:
        return $default(_that.sucesso, _that.descricao, _that.tipo);
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
    TResult Function(bool sucesso, String descricao, TipoConsultaGuia tipo)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ConsultaGuia():
        return $default(_that.sucesso, _that.descricao, _that.tipo);
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
    TResult? Function(bool sucesso, String descricao, TipoConsultaGuia tipo)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ConsultaGuia() when $default != null:
        return $default(_that.sucesso, _that.descricao, _that.tipo);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ConsultaGuia implements ConsultaGuia {
  const _ConsultaGuia(
      {required this.sucesso,
      required this.descricao,
      this.tipo = TipoConsultaGuia.elegibilidade});

  @override
  final bool sucesso;
  @override
  final String descricao;
  @override
  @JsonKey()
  final TipoConsultaGuia tipo;

  /// Create a copy of ConsultaGuia
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ConsultaGuiaCopyWith<_ConsultaGuia> get copyWith =>
      __$ConsultaGuiaCopyWithImpl<_ConsultaGuia>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ConsultaGuia &&
            (identical(other.sucesso, sucesso) || other.sucesso == sucesso) &&
            (identical(other.descricao, descricao) ||
                other.descricao == descricao) &&
            (identical(other.tipo, tipo) || other.tipo == tipo));
  }

  @override
  int get hashCode => Object.hash(runtimeType, sucesso, descricao, tipo);

  @override
  String toString() {
    return 'ConsultaGuia(sucesso: $sucesso, descricao: $descricao, tipo: $tipo)';
  }
}

/// @nodoc
abstract mixin class _$ConsultaGuiaCopyWith<$Res>
    implements $ConsultaGuiaCopyWith<$Res> {
  factory _$ConsultaGuiaCopyWith(
          _ConsultaGuia value, $Res Function(_ConsultaGuia) _then) =
      __$ConsultaGuiaCopyWithImpl;
  @override
  @useResult
  $Res call({bool sucesso, String descricao, TipoConsultaGuia tipo});
}

/// @nodoc
class __$ConsultaGuiaCopyWithImpl<$Res>
    implements _$ConsultaGuiaCopyWith<$Res> {
  __$ConsultaGuiaCopyWithImpl(this._self, this._then);

  final _ConsultaGuia _self;
  final $Res Function(_ConsultaGuia) _then;

  /// Create a copy of ConsultaGuia
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? sucesso = null,
    Object? descricao = null,
    Object? tipo = null,
  }) {
    return _then(_ConsultaGuia(
      sucesso: null == sucesso
          ? _self.sucesso
          : sucesso // ignore: cast_nullable_to_non_nullable
              as bool,
      descricao: null == descricao
          ? _self.descricao
          : descricao // ignore: cast_nullable_to_non_nullable
              as String,
      tipo: null == tipo
          ? _self.tipo
          : tipo // ignore: cast_nullable_to_non_nullable
              as TipoConsultaGuia,
    ));
  }
}

// dart format on
