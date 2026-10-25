// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'procedimento.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Procedimento {
  String get codigo;
  int get quantidade;

  /// Create a copy of Procedimento
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ProcedimentoCopyWith<Procedimento> get copyWith =>
      _$ProcedimentoCopyWithImpl<Procedimento>(
          this as Procedimento, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Procedimento &&
            (identical(other.codigo, codigo) || other.codigo == codigo) &&
            (identical(other.quantidade, quantidade) ||
                other.quantidade == quantidade));
  }

  @override
  int get hashCode => Object.hash(runtimeType, codigo, quantidade);

  @override
  String toString() {
    return 'Procedimento(codigo: $codigo, quantidade: $quantidade)';
  }
}

/// @nodoc
abstract mixin class $ProcedimentoCopyWith<$Res> {
  factory $ProcedimentoCopyWith(
          Procedimento value, $Res Function(Procedimento) _then) =
      _$ProcedimentoCopyWithImpl;
  @useResult
  $Res call({String codigo, int quantidade});
}

/// @nodoc
class _$ProcedimentoCopyWithImpl<$Res> implements $ProcedimentoCopyWith<$Res> {
  _$ProcedimentoCopyWithImpl(this._self, this._then);

  final Procedimento _self;
  final $Res Function(Procedimento) _then;

  /// Create a copy of Procedimento
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? codigo = null,
    Object? quantidade = null,
  }) {
    return _then(_self.copyWith(
      codigo: null == codigo
          ? _self.codigo
          : codigo // ignore: cast_nullable_to_non_nullable
              as String,
      quantidade: null == quantidade
          ? _self.quantidade
          : quantidade // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [Procedimento].
extension ProcedimentoPatterns on Procedimento {
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
    TResult Function(_Procedimento value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Procedimento() when $default != null:
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
    TResult Function(_Procedimento value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Procedimento():
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
    TResult? Function(_Procedimento value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Procedimento() when $default != null:
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
    TResult Function(String codigo, int quantidade)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Procedimento() when $default != null:
        return $default(_that.codigo, _that.quantidade);
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
    TResult Function(String codigo, int quantidade) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Procedimento():
        return $default(_that.codigo, _that.quantidade);
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
    TResult? Function(String codigo, int quantidade)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Procedimento() when $default != null:
        return $default(_that.codigo, _that.quantidade);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _Procedimento implements Procedimento {
  const _Procedimento({required this.codigo, required this.quantidade});

  @override
  final String codigo;
  @override
  final int quantidade;

  /// Create a copy of Procedimento
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ProcedimentoCopyWith<_Procedimento> get copyWith =>
      __$ProcedimentoCopyWithImpl<_Procedimento>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Procedimento &&
            (identical(other.codigo, codigo) || other.codigo == codigo) &&
            (identical(other.quantidade, quantidade) ||
                other.quantidade == quantidade));
  }

  @override
  int get hashCode => Object.hash(runtimeType, codigo, quantidade);

  @override
  String toString() {
    return 'Procedimento(codigo: $codigo, quantidade: $quantidade)';
  }
}

/// @nodoc
abstract mixin class _$ProcedimentoCopyWith<$Res>
    implements $ProcedimentoCopyWith<$Res> {
  factory _$ProcedimentoCopyWith(
          _Procedimento value, $Res Function(_Procedimento) _then) =
      __$ProcedimentoCopyWithImpl;
  @override
  @useResult
  $Res call({String codigo, int quantidade});
}

/// @nodoc
class __$ProcedimentoCopyWithImpl<$Res>
    implements _$ProcedimentoCopyWith<$Res> {
  __$ProcedimentoCopyWithImpl(this._self, this._then);

  final _Procedimento _self;
  final $Res Function(_Procedimento) _then;

  /// Create a copy of Procedimento
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? codigo = null,
    Object? quantidade = null,
  }) {
    return _then(_Procedimento(
      codigo: null == codigo
          ? _self.codigo
          : codigo // ignore: cast_nullable_to_non_nullable
              as String,
      quantidade: null == quantidade
          ? _self.quantidade
          : quantidade // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
