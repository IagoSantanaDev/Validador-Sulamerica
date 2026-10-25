// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tuss_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TussItem {
  String get id;
  String get nome;
  String get tabela;
  String? get inicioVigencia;
  String? get fimVigencia;

  /// Create a copy of TussItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TussItemCopyWith<TussItem> get copyWith =>
      _$TussItemCopyWithImpl<TussItem>(this as TussItem, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TussItem &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.nome, nome) || other.nome == nome) &&
            (identical(other.tabela, tabela) || other.tabela == tabela) &&
            (identical(other.inicioVigencia, inicioVigencia) ||
                other.inicioVigencia == inicioVigencia) &&
            (identical(other.fimVigencia, fimVigencia) ||
                other.fimVigencia == fimVigencia));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, id, nome, tabela, inicioVigencia, fimVigencia);

  @override
  String toString() {
    return 'TussItem(id: $id, nome: $nome, tabela: $tabela, inicioVigencia: $inicioVigencia, fimVigencia: $fimVigencia)';
  }
}

/// @nodoc
abstract mixin class $TussItemCopyWith<$Res> {
  factory $TussItemCopyWith(TussItem value, $Res Function(TussItem) _then) =
      _$TussItemCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String nome,
      String tabela,
      String? inicioVigencia,
      String? fimVigencia});
}

/// @nodoc
class _$TussItemCopyWithImpl<$Res> implements $TussItemCopyWith<$Res> {
  _$TussItemCopyWithImpl(this._self, this._then);

  final TussItem _self;
  final $Res Function(TussItem) _then;

  /// Create a copy of TussItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? nome = null,
    Object? tabela = null,
    Object? inicioVigencia = freezed,
    Object? fimVigencia = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      nome: null == nome
          ? _self.nome
          : nome // ignore: cast_nullable_to_non_nullable
              as String,
      tabela: null == tabela
          ? _self.tabela
          : tabela // ignore: cast_nullable_to_non_nullable
              as String,
      inicioVigencia: freezed == inicioVigencia
          ? _self.inicioVigencia
          : inicioVigencia // ignore: cast_nullable_to_non_nullable
              as String?,
      fimVigencia: freezed == fimVigencia
          ? _self.fimVigencia
          : fimVigencia // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [TussItem].
extension TussItemPatterns on TussItem {
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
    TResult Function(_TussItem value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TussItem() when $default != null:
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
    TResult Function(_TussItem value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TussItem():
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
    TResult? Function(_TussItem value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TussItem() when $default != null:
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
    TResult Function(String id, String nome, String tabela,
            String? inicioVigencia, String? fimVigencia)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TussItem() when $default != null:
        return $default(_that.id, _that.nome, _that.tabela,
            _that.inicioVigencia, _that.fimVigencia);
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
    TResult Function(String id, String nome, String tabela,
            String? inicioVigencia, String? fimVigencia)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TussItem():
        return $default(_that.id, _that.nome, _that.tabela,
            _that.inicioVigencia, _that.fimVigencia);
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
    TResult? Function(String id, String nome, String tabela,
            String? inicioVigencia, String? fimVigencia)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TussItem() when $default != null:
        return $default(_that.id, _that.nome, _that.tabela,
            _that.inicioVigencia, _that.fimVigencia);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _TussItem implements TussItem {
  const _TussItem(
      {required this.id,
      required this.nome,
      required this.tabela,
      this.inicioVigencia,
      this.fimVigencia});

  @override
  final String id;
  @override
  final String nome;
  @override
  final String tabela;
  @override
  final String? inicioVigencia;
  @override
  final String? fimVigencia;

  /// Create a copy of TussItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TussItemCopyWith<_TussItem> get copyWith =>
      __$TussItemCopyWithImpl<_TussItem>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TussItem &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.nome, nome) || other.nome == nome) &&
            (identical(other.tabela, tabela) || other.tabela == tabela) &&
            (identical(other.inicioVigencia, inicioVigencia) ||
                other.inicioVigencia == inicioVigencia) &&
            (identical(other.fimVigencia, fimVigencia) ||
                other.fimVigencia == fimVigencia));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, id, nome, tabela, inicioVigencia, fimVigencia);

  @override
  String toString() {
    return 'TussItem(id: $id, nome: $nome, tabela: $tabela, inicioVigencia: $inicioVigencia, fimVigencia: $fimVigencia)';
  }
}

/// @nodoc
abstract mixin class _$TussItemCopyWith<$Res>
    implements $TussItemCopyWith<$Res> {
  factory _$TussItemCopyWith(_TussItem value, $Res Function(_TussItem) _then) =
      __$TussItemCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String nome,
      String tabela,
      String? inicioVigencia,
      String? fimVigencia});
}

/// @nodoc
class __$TussItemCopyWithImpl<$Res> implements _$TussItemCopyWith<$Res> {
  __$TussItemCopyWithImpl(this._self, this._then);

  final _TussItem _self;
  final $Res Function(_TussItem) _then;

  /// Create a copy of TussItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? nome = null,
    Object? tabela = null,
    Object? inicioVigencia = freezed,
    Object? fimVigencia = freezed,
  }) {
    return _then(_TussItem(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      nome: null == nome
          ? _self.nome
          : nome // ignore: cast_nullable_to_non_nullable
              as String,
      tabela: null == tabela
          ? _self.tabela
          : tabela // ignore: cast_nullable_to_non_nullable
              as String,
      inicioVigencia: freezed == inicioVigencia
          ? _self.inicioVigencia
          : inicioVigencia // ignore: cast_nullable_to_non_nullable
              as String?,
      fimVigencia: freezed == fimVigencia
          ? _self.fimVigencia
          : fimVigencia // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
