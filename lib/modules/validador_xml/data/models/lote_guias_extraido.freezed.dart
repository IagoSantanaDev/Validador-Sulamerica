// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'lote_guias_extraido.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LoteGuiasExtraido {
  InformacoesLote get informacoes;
  List<GuiaTiss> get guias;

  /// Create a copy of LoteGuiasExtraido
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LoteGuiasExtraidoCopyWith<LoteGuiasExtraido> get copyWith =>
      _$LoteGuiasExtraidoCopyWithImpl<LoteGuiasExtraido>(
          this as LoteGuiasExtraido, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LoteGuiasExtraido &&
            (identical(other.informacoes, informacoes) ||
                other.informacoes == informacoes) &&
            const DeepCollectionEquality().equals(other.guias, guias));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, informacoes, const DeepCollectionEquality().hash(guias));

  @override
  String toString() {
    return 'LoteGuiasExtraido(informacoes: $informacoes, guias: $guias)';
  }
}

/// @nodoc
abstract mixin class $LoteGuiasExtraidoCopyWith<$Res> {
  factory $LoteGuiasExtraidoCopyWith(
          LoteGuiasExtraido value, $Res Function(LoteGuiasExtraido) _then) =
      _$LoteGuiasExtraidoCopyWithImpl;
  @useResult
  $Res call({InformacoesLote informacoes, List<GuiaTiss> guias});

  $InformacoesLoteCopyWith<$Res> get informacoes;
}

/// @nodoc
class _$LoteGuiasExtraidoCopyWithImpl<$Res>
    implements $LoteGuiasExtraidoCopyWith<$Res> {
  _$LoteGuiasExtraidoCopyWithImpl(this._self, this._then);

  final LoteGuiasExtraido _self;
  final $Res Function(LoteGuiasExtraido) _then;

  /// Create a copy of LoteGuiasExtraido
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? informacoes = null,
    Object? guias = null,
  }) {
    return _then(_self.copyWith(
      informacoes: null == informacoes
          ? _self.informacoes
          : informacoes // ignore: cast_nullable_to_non_nullable
              as InformacoesLote,
      guias: null == guias
          ? _self.guias
          : guias // ignore: cast_nullable_to_non_nullable
              as List<GuiaTiss>,
    ));
  }

  /// Create a copy of LoteGuiasExtraido
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $InformacoesLoteCopyWith<$Res> get informacoes {
    return $InformacoesLoteCopyWith<$Res>(_self.informacoes, (value) {
      return _then(_self.copyWith(informacoes: value));
    });
  }
}

/// Adds pattern-matching-related methods to [LoteGuiasExtraido].
extension LoteGuiasExtraidoPatterns on LoteGuiasExtraido {
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
    TResult Function(_LoteGuiasExtraido value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LoteGuiasExtraido() when $default != null:
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
    TResult Function(_LoteGuiasExtraido value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LoteGuiasExtraido():
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
    TResult? Function(_LoteGuiasExtraido value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LoteGuiasExtraido() when $default != null:
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
    TResult Function(InformacoesLote informacoes, List<GuiaTiss> guias)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LoteGuiasExtraido() when $default != null:
        return $default(_that.informacoes, _that.guias);
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
    TResult Function(InformacoesLote informacoes, List<GuiaTiss> guias)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LoteGuiasExtraido():
        return $default(_that.informacoes, _that.guias);
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
    TResult? Function(InformacoesLote informacoes, List<GuiaTiss> guias)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LoteGuiasExtraido() when $default != null:
        return $default(_that.informacoes, _that.guias);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _LoteGuiasExtraido implements LoteGuiasExtraido {
  const _LoteGuiasExtraido(
      {required this.informacoes, required final List<GuiaTiss> guias})
      : _guias = guias;

  @override
  final InformacoesLote informacoes;
  final List<GuiaTiss> _guias;
  @override
  List<GuiaTiss> get guias {
    if (_guias is EqualUnmodifiableListView) return _guias;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_guias);
  }

  /// Create a copy of LoteGuiasExtraido
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$LoteGuiasExtraidoCopyWith<_LoteGuiasExtraido> get copyWith =>
      __$LoteGuiasExtraidoCopyWithImpl<_LoteGuiasExtraido>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _LoteGuiasExtraido &&
            (identical(other.informacoes, informacoes) ||
                other.informacoes == informacoes) &&
            const DeepCollectionEquality().equals(other._guias, _guias));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, informacoes, const DeepCollectionEquality().hash(_guias));

  @override
  String toString() {
    return 'LoteGuiasExtraido(informacoes: $informacoes, guias: $guias)';
  }
}

/// @nodoc
abstract mixin class _$LoteGuiasExtraidoCopyWith<$Res>
    implements $LoteGuiasExtraidoCopyWith<$Res> {
  factory _$LoteGuiasExtraidoCopyWith(
          _LoteGuiasExtraido value, $Res Function(_LoteGuiasExtraido) _then) =
      __$LoteGuiasExtraidoCopyWithImpl;
  @override
  @useResult
  $Res call({InformacoesLote informacoes, List<GuiaTiss> guias});

  @override
  $InformacoesLoteCopyWith<$Res> get informacoes;
}

/// @nodoc
class __$LoteGuiasExtraidoCopyWithImpl<$Res>
    implements _$LoteGuiasExtraidoCopyWith<$Res> {
  __$LoteGuiasExtraidoCopyWithImpl(this._self, this._then);

  final _LoteGuiasExtraido _self;
  final $Res Function(_LoteGuiasExtraido) _then;

  /// Create a copy of LoteGuiasExtraido
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? informacoes = null,
    Object? guias = null,
  }) {
    return _then(_LoteGuiasExtraido(
      informacoes: null == informacoes
          ? _self.informacoes
          : informacoes // ignore: cast_nullable_to_non_nullable
              as InformacoesLote,
      guias: null == guias
          ? _self._guias
          : guias // ignore: cast_nullable_to_non_nullable
              as List<GuiaTiss>,
    ));
  }

  /// Create a copy of LoteGuiasExtraido
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $InformacoesLoteCopyWith<$Res> get informacoes {
    return $InformacoesLoteCopyWith<$Res>(_self.informacoes, (value) {
      return _then(_self.copyWith(informacoes: value));
    });
  }
}

// dart format on
