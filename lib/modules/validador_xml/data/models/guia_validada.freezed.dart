// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'guia_validada.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GuiaValidada {
  GuiaTiss get guia;
  List<ErroValidacao> get erros;
  List<ConsultaGuia> get consultas;

  /// Create a copy of GuiaValidada
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $GuiaValidadaCopyWith<GuiaValidada> get copyWith =>
      _$GuiaValidadaCopyWithImpl<GuiaValidada>(
          this as GuiaValidada, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is GuiaValidada &&
            (identical(other.guia, guia) || other.guia == guia) &&
            const DeepCollectionEquality().equals(other.erros, erros) &&
            const DeepCollectionEquality().equals(other.consultas, consultas));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      guia,
      const DeepCollectionEquality().hash(erros),
      const DeepCollectionEquality().hash(consultas));

  @override
  String toString() {
    return 'GuiaValidada(guia: $guia, erros: $erros, consultas: $consultas)';
  }
}

/// @nodoc
abstract mixin class $GuiaValidadaCopyWith<$Res> {
  factory $GuiaValidadaCopyWith(
          GuiaValidada value, $Res Function(GuiaValidada) _then) =
      _$GuiaValidadaCopyWithImpl;
  @useResult
  $Res call(
      {GuiaTiss guia, List<ErroValidacao> erros, List<ConsultaGuia> consultas});

  $GuiaTissCopyWith<$Res> get guia;
}

/// @nodoc
class _$GuiaValidadaCopyWithImpl<$Res> implements $GuiaValidadaCopyWith<$Res> {
  _$GuiaValidadaCopyWithImpl(this._self, this._then);

  final GuiaValidada _self;
  final $Res Function(GuiaValidada) _then;

  /// Create a copy of GuiaValidada
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? guia = null,
    Object? erros = null,
    Object? consultas = null,
  }) {
    return _then(_self.copyWith(
      guia: null == guia
          ? _self.guia
          : guia // ignore: cast_nullable_to_non_nullable
              as GuiaTiss,
      erros: null == erros
          ? _self.erros
          : erros // ignore: cast_nullable_to_non_nullable
              as List<ErroValidacao>,
      consultas: null == consultas
          ? _self.consultas
          : consultas // ignore: cast_nullable_to_non_nullable
              as List<ConsultaGuia>,
    ));
  }

  /// Create a copy of GuiaValidada
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GuiaTissCopyWith<$Res> get guia {
    return $GuiaTissCopyWith<$Res>(_self.guia, (value) {
      return _then(_self.copyWith(guia: value));
    });
  }
}

/// Adds pattern-matching-related methods to [GuiaValidada].
extension GuiaValidadaPatterns on GuiaValidada {
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
    TResult Function(_GuiaValidada value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _GuiaValidada() when $default != null:
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
    TResult Function(_GuiaValidada value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GuiaValidada():
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
    TResult? Function(_GuiaValidada value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GuiaValidada() when $default != null:
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
    TResult Function(GuiaTiss guia, List<ErroValidacao> erros,
            List<ConsultaGuia> consultas)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _GuiaValidada() when $default != null:
        return $default(_that.guia, _that.erros, _that.consultas);
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
    TResult Function(GuiaTiss guia, List<ErroValidacao> erros,
            List<ConsultaGuia> consultas)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GuiaValidada():
        return $default(_that.guia, _that.erros, _that.consultas);
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
    TResult? Function(GuiaTiss guia, List<ErroValidacao> erros,
            List<ConsultaGuia> consultas)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GuiaValidada() when $default != null:
        return $default(_that.guia, _that.erros, _that.consultas);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _GuiaValidada extends GuiaValidada {
  const _GuiaValidada(
      {required this.guia,
      required final List<ErroValidacao> erros,
      final List<ConsultaGuia> consultas = const []})
      : _erros = erros,
        _consultas = consultas,
        super._();

  @override
  final GuiaTiss guia;
  final List<ErroValidacao> _erros;
  @override
  List<ErroValidacao> get erros {
    if (_erros is EqualUnmodifiableListView) return _erros;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_erros);
  }

  final List<ConsultaGuia> _consultas;
  @override
  @JsonKey()
  List<ConsultaGuia> get consultas {
    if (_consultas is EqualUnmodifiableListView) return _consultas;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_consultas);
  }

  /// Create a copy of GuiaValidada
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$GuiaValidadaCopyWith<_GuiaValidada> get copyWith =>
      __$GuiaValidadaCopyWithImpl<_GuiaValidada>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _GuiaValidada &&
            (identical(other.guia, guia) || other.guia == guia) &&
            const DeepCollectionEquality().equals(other._erros, _erros) &&
            const DeepCollectionEquality()
                .equals(other._consultas, _consultas));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      guia,
      const DeepCollectionEquality().hash(_erros),
      const DeepCollectionEquality().hash(_consultas));

  @override
  String toString() {
    return 'GuiaValidada(guia: $guia, erros: $erros, consultas: $consultas)';
  }
}

/// @nodoc
abstract mixin class _$GuiaValidadaCopyWith<$Res>
    implements $GuiaValidadaCopyWith<$Res> {
  factory _$GuiaValidadaCopyWith(
          _GuiaValidada value, $Res Function(_GuiaValidada) _then) =
      __$GuiaValidadaCopyWithImpl;
  @override
  @useResult
  $Res call(
      {GuiaTiss guia, List<ErroValidacao> erros, List<ConsultaGuia> consultas});

  @override
  $GuiaTissCopyWith<$Res> get guia;
}

/// @nodoc
class __$GuiaValidadaCopyWithImpl<$Res>
    implements _$GuiaValidadaCopyWith<$Res> {
  __$GuiaValidadaCopyWithImpl(this._self, this._then);

  final _GuiaValidada _self;
  final $Res Function(_GuiaValidada) _then;

  /// Create a copy of GuiaValidada
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? guia = null,
    Object? erros = null,
    Object? consultas = null,
  }) {
    return _then(_GuiaValidada(
      guia: null == guia
          ? _self.guia
          : guia // ignore: cast_nullable_to_non_nullable
              as GuiaTiss,
      erros: null == erros
          ? _self._erros
          : erros // ignore: cast_nullable_to_non_nullable
              as List<ErroValidacao>,
      consultas: null == consultas
          ? _self._consultas
          : consultas // ignore: cast_nullable_to_non_nullable
              as List<ConsultaGuia>,
    ));
  }

  /// Create a copy of GuiaValidada
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GuiaTissCopyWith<$Res> get guia {
    return $GuiaTissCopyWith<$Res>(_self.guia, (value) {
      return _then(_self.copyWith(guia: value));
    });
  }
}

// dart format on
