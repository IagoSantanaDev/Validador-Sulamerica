// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profissional_solicitante.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProfissionalSolicitante {
  String? get numeroConselho;

  /// Create a copy of ProfissionalSolicitante
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ProfissionalSolicitanteCopyWith<ProfissionalSolicitante> get copyWith =>
      _$ProfissionalSolicitanteCopyWithImpl<ProfissionalSolicitante>(
          this as ProfissionalSolicitante, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ProfissionalSolicitante &&
            (identical(other.numeroConselho, numeroConselho) ||
                other.numeroConselho == numeroConselho));
  }

  @override
  int get hashCode => Object.hash(runtimeType, numeroConselho);

  @override
  String toString() {
    return 'ProfissionalSolicitante(numeroConselho: $numeroConselho)';
  }
}

/// @nodoc
abstract mixin class $ProfissionalSolicitanteCopyWith<$Res> {
  factory $ProfissionalSolicitanteCopyWith(ProfissionalSolicitante value,
          $Res Function(ProfissionalSolicitante) _then) =
      _$ProfissionalSolicitanteCopyWithImpl;
  @useResult
  $Res call({String? numeroConselho});
}

/// @nodoc
class _$ProfissionalSolicitanteCopyWithImpl<$Res>
    implements $ProfissionalSolicitanteCopyWith<$Res> {
  _$ProfissionalSolicitanteCopyWithImpl(this._self, this._then);

  final ProfissionalSolicitante _self;
  final $Res Function(ProfissionalSolicitante) _then;

  /// Create a copy of ProfissionalSolicitante
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? numeroConselho = freezed,
  }) {
    return _then(_self.copyWith(
      numeroConselho: freezed == numeroConselho
          ? _self.numeroConselho
          : numeroConselho // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [ProfissionalSolicitante].
extension ProfissionalSolicitantePatterns on ProfissionalSolicitante {
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
    TResult Function(_ProfissionalSolicitante value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProfissionalSolicitante() when $default != null:
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
    TResult Function(_ProfissionalSolicitante value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProfissionalSolicitante():
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
    TResult? Function(_ProfissionalSolicitante value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProfissionalSolicitante() when $default != null:
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
    TResult Function(String? numeroConselho)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProfissionalSolicitante() when $default != null:
        return $default(_that.numeroConselho);
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
    TResult Function(String? numeroConselho) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProfissionalSolicitante():
        return $default(_that.numeroConselho);
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
    TResult? Function(String? numeroConselho)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProfissionalSolicitante() when $default != null:
        return $default(_that.numeroConselho);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ProfissionalSolicitante implements ProfissionalSolicitante {
  const _ProfissionalSolicitante({this.numeroConselho});

  @override
  final String? numeroConselho;

  /// Create a copy of ProfissionalSolicitante
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ProfissionalSolicitanteCopyWith<_ProfissionalSolicitante> get copyWith =>
      __$ProfissionalSolicitanteCopyWithImpl<_ProfissionalSolicitante>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ProfissionalSolicitante &&
            (identical(other.numeroConselho, numeroConselho) ||
                other.numeroConselho == numeroConselho));
  }

  @override
  int get hashCode => Object.hash(runtimeType, numeroConselho);

  @override
  String toString() {
    return 'ProfissionalSolicitante(numeroConselho: $numeroConselho)';
  }
}

/// @nodoc
abstract mixin class _$ProfissionalSolicitanteCopyWith<$Res>
    implements $ProfissionalSolicitanteCopyWith<$Res> {
  factory _$ProfissionalSolicitanteCopyWith(_ProfissionalSolicitante value,
          $Res Function(_ProfissionalSolicitante) _then) =
      __$ProfissionalSolicitanteCopyWithImpl;
  @override
  @useResult
  $Res call({String? numeroConselho});
}

/// @nodoc
class __$ProfissionalSolicitanteCopyWithImpl<$Res>
    implements _$ProfissionalSolicitanteCopyWith<$Res> {
  __$ProfissionalSolicitanteCopyWithImpl(this._self, this._then);

  final _ProfissionalSolicitante _self;
  final $Res Function(_ProfissionalSolicitante) _then;

  /// Create a copy of ProfissionalSolicitante
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? numeroConselho = freezed,
  }) {
    return _then(_ProfissionalSolicitante(
      numeroConselho: freezed == numeroConselho
          ? _self.numeroConselho
          : numeroConselho // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
