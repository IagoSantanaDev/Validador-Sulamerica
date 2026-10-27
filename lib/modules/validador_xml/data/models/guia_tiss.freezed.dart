// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'guia_tiss.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GuiaTiss {
  String get numeroGuiaPrestador;
  String? get numeroCarteira;
  String? get senha;
  String? get dataAutorizacao;
  String? get nomeBeneficiario;
  ProfissionalSolicitante? get solicitante;
  List<Procedimento> get procedimentos;

  /// Create a copy of GuiaTiss
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $GuiaTissCopyWith<GuiaTiss> get copyWith =>
      _$GuiaTissCopyWithImpl<GuiaTiss>(this as GuiaTiss, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is GuiaTiss &&
            (identical(other.numeroGuiaPrestador, numeroGuiaPrestador) ||
                other.numeroGuiaPrestador == numeroGuiaPrestador) &&
            (identical(other.numeroCarteira, numeroCarteira) ||
                other.numeroCarteira == numeroCarteira) &&
            (identical(other.senha, senha) || other.senha == senha) &&
            (identical(other.dataAutorizacao, dataAutorizacao) ||
                other.dataAutorizacao == dataAutorizacao) &&
            (identical(other.nomeBeneficiario, nomeBeneficiario) ||
                other.nomeBeneficiario == nomeBeneficiario) &&
            (identical(other.solicitante, solicitante) ||
                other.solicitante == solicitante) &&
            const DeepCollectionEquality()
                .equals(other.procedimentos, procedimentos));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      numeroGuiaPrestador,
      numeroCarteira,
      senha,
      dataAutorizacao,
      nomeBeneficiario,
      solicitante,
      const DeepCollectionEquality().hash(procedimentos));

  @override
  String toString() {
    return 'GuiaTiss(numeroGuiaPrestador: $numeroGuiaPrestador, numeroCarteira: $numeroCarteira, senha: $senha, dataAutorizacao: $dataAutorizacao, nomeBeneficiario: $nomeBeneficiario, solicitante: $solicitante, procedimentos: $procedimentos)';
  }
}

/// @nodoc
abstract mixin class $GuiaTissCopyWith<$Res> {
  factory $GuiaTissCopyWith(GuiaTiss value, $Res Function(GuiaTiss) _then) =
      _$GuiaTissCopyWithImpl;
  @useResult
  $Res call(
      {String numeroGuiaPrestador,
      String? numeroCarteira,
      String? senha,
      String? dataAutorizacao,
      String? nomeBeneficiario,
      ProfissionalSolicitante? solicitante,
      List<Procedimento> procedimentos});

  $ProfissionalSolicitanteCopyWith<$Res>? get solicitante;
}

/// @nodoc
class _$GuiaTissCopyWithImpl<$Res> implements $GuiaTissCopyWith<$Res> {
  _$GuiaTissCopyWithImpl(this._self, this._then);

  final GuiaTiss _self;
  final $Res Function(GuiaTiss) _then;

  /// Create a copy of GuiaTiss
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? numeroGuiaPrestador = null,
    Object? numeroCarteira = freezed,
    Object? senha = freezed,
    Object? dataAutorizacao = freezed,
    Object? nomeBeneficiario = freezed,
    Object? solicitante = freezed,
    Object? procedimentos = null,
  }) {
    return _then(_self.copyWith(
      numeroGuiaPrestador: null == numeroGuiaPrestador
          ? _self.numeroGuiaPrestador
          : numeroGuiaPrestador // ignore: cast_nullable_to_non_nullable
              as String,
      numeroCarteira: freezed == numeroCarteira
          ? _self.numeroCarteira
          : numeroCarteira // ignore: cast_nullable_to_non_nullable
              as String?,
      senha: freezed == senha
          ? _self.senha
          : senha // ignore: cast_nullable_to_non_nullable
              as String?,
      dataAutorizacao: freezed == dataAutorizacao
          ? _self.dataAutorizacao
          : dataAutorizacao // ignore: cast_nullable_to_non_nullable
              as String?,
      nomeBeneficiario: freezed == nomeBeneficiario
          ? _self.nomeBeneficiario
          : nomeBeneficiario // ignore: cast_nullable_to_non_nullable
              as String?,
      solicitante: freezed == solicitante
          ? _self.solicitante
          : solicitante // ignore: cast_nullable_to_non_nullable
              as ProfissionalSolicitante?,
      procedimentos: null == procedimentos
          ? _self.procedimentos
          : procedimentos // ignore: cast_nullable_to_non_nullable
              as List<Procedimento>,
    ));
  }

  /// Create a copy of GuiaTiss
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ProfissionalSolicitanteCopyWith<$Res>? get solicitante {
    if (_self.solicitante == null) {
      return null;
    }

    return $ProfissionalSolicitanteCopyWith<$Res>(_self.solicitante!, (value) {
      return _then(_self.copyWith(solicitante: value));
    });
  }
}

/// Adds pattern-matching-related methods to [GuiaTiss].
extension GuiaTissPatterns on GuiaTiss {
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
    TResult Function(_GuiaTiss value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _GuiaTiss() when $default != null:
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
    TResult Function(_GuiaTiss value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GuiaTiss():
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
    TResult? Function(_GuiaTiss value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GuiaTiss() when $default != null:
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
    TResult Function(
            String numeroGuiaPrestador,
            String? numeroCarteira,
            String? senha,
            String? dataAutorizacao,
            String? nomeBeneficiario,
            ProfissionalSolicitante? solicitante,
            List<Procedimento> procedimentos)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _GuiaTiss() when $default != null:
        return $default(
            _that.numeroGuiaPrestador,
            _that.numeroCarteira,
            _that.senha,
            _that.dataAutorizacao,
            _that.nomeBeneficiario,
            _that.solicitante,
            _that.procedimentos);
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
    TResult Function(
            String numeroGuiaPrestador,
            String? numeroCarteira,
            String? senha,
            String? dataAutorizacao,
            String? nomeBeneficiario,
            ProfissionalSolicitante? solicitante,
            List<Procedimento> procedimentos)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GuiaTiss():
        return $default(
            _that.numeroGuiaPrestador,
            _that.numeroCarteira,
            _that.senha,
            _that.dataAutorizacao,
            _that.nomeBeneficiario,
            _that.solicitante,
            _that.procedimentos);
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
    TResult? Function(
            String numeroGuiaPrestador,
            String? numeroCarteira,
            String? senha,
            String? dataAutorizacao,
            String? nomeBeneficiario,
            ProfissionalSolicitante? solicitante,
            List<Procedimento> procedimentos)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GuiaTiss() when $default != null:
        return $default(
            _that.numeroGuiaPrestador,
            _that.numeroCarteira,
            _that.senha,
            _that.dataAutorizacao,
            _that.nomeBeneficiario,
            _that.solicitante,
            _that.procedimentos);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _GuiaTiss implements GuiaTiss {
  const _GuiaTiss(
      {required this.numeroGuiaPrestador,
      required this.numeroCarteira,
      required this.senha,
      this.dataAutorizacao,
      this.nomeBeneficiario,
      this.solicitante,
      final List<Procedimento> procedimentos = const []})
      : _procedimentos = procedimentos;

  @override
  final String numeroGuiaPrestador;
  @override
  final String? numeroCarteira;
  @override
  final String? senha;
  @override
  final String? dataAutorizacao;
  @override
  final String? nomeBeneficiario;
  @override
  final ProfissionalSolicitante? solicitante;
  final List<Procedimento> _procedimentos;
  @override
  @JsonKey()
  List<Procedimento> get procedimentos {
    if (_procedimentos is EqualUnmodifiableListView) return _procedimentos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_procedimentos);
  }

  /// Create a copy of GuiaTiss
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$GuiaTissCopyWith<_GuiaTiss> get copyWith =>
      __$GuiaTissCopyWithImpl<_GuiaTiss>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _GuiaTiss &&
            (identical(other.numeroGuiaPrestador, numeroGuiaPrestador) ||
                other.numeroGuiaPrestador == numeroGuiaPrestador) &&
            (identical(other.numeroCarteira, numeroCarteira) ||
                other.numeroCarteira == numeroCarteira) &&
            (identical(other.senha, senha) || other.senha == senha) &&
            (identical(other.dataAutorizacao, dataAutorizacao) ||
                other.dataAutorizacao == dataAutorizacao) &&
            (identical(other.nomeBeneficiario, nomeBeneficiario) ||
                other.nomeBeneficiario == nomeBeneficiario) &&
            (identical(other.solicitante, solicitante) ||
                other.solicitante == solicitante) &&
            const DeepCollectionEquality()
                .equals(other._procedimentos, _procedimentos));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      numeroGuiaPrestador,
      numeroCarteira,
      senha,
      dataAutorizacao,
      nomeBeneficiario,
      solicitante,
      const DeepCollectionEquality().hash(_procedimentos));

  @override
  String toString() {
    return 'GuiaTiss(numeroGuiaPrestador: $numeroGuiaPrestador, numeroCarteira: $numeroCarteira, senha: $senha, dataAutorizacao: $dataAutorizacao, nomeBeneficiario: $nomeBeneficiario, solicitante: $solicitante, procedimentos: $procedimentos)';
  }
}

/// @nodoc
abstract mixin class _$GuiaTissCopyWith<$Res>
    implements $GuiaTissCopyWith<$Res> {
  factory _$GuiaTissCopyWith(_GuiaTiss value, $Res Function(_GuiaTiss) _then) =
      __$GuiaTissCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String numeroGuiaPrestador,
      String? numeroCarteira,
      String? senha,
      String? dataAutorizacao,
      String? nomeBeneficiario,
      ProfissionalSolicitante? solicitante,
      List<Procedimento> procedimentos});

  @override
  $ProfissionalSolicitanteCopyWith<$Res>? get solicitante;
}

/// @nodoc
class __$GuiaTissCopyWithImpl<$Res> implements _$GuiaTissCopyWith<$Res> {
  __$GuiaTissCopyWithImpl(this._self, this._then);

  final _GuiaTiss _self;
  final $Res Function(_GuiaTiss) _then;

  /// Create a copy of GuiaTiss
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? numeroGuiaPrestador = null,
    Object? numeroCarteira = freezed,
    Object? senha = freezed,
    Object? dataAutorizacao = freezed,
    Object? nomeBeneficiario = freezed,
    Object? solicitante = freezed,
    Object? procedimentos = null,
  }) {
    return _then(_GuiaTiss(
      numeroGuiaPrestador: null == numeroGuiaPrestador
          ? _self.numeroGuiaPrestador
          : numeroGuiaPrestador // ignore: cast_nullable_to_non_nullable
              as String,
      numeroCarteira: freezed == numeroCarteira
          ? _self.numeroCarteira
          : numeroCarteira // ignore: cast_nullable_to_non_nullable
              as String?,
      senha: freezed == senha
          ? _self.senha
          : senha // ignore: cast_nullable_to_non_nullable
              as String?,
      dataAutorizacao: freezed == dataAutorizacao
          ? _self.dataAutorizacao
          : dataAutorizacao // ignore: cast_nullable_to_non_nullable
              as String?,
      nomeBeneficiario: freezed == nomeBeneficiario
          ? _self.nomeBeneficiario
          : nomeBeneficiario // ignore: cast_nullable_to_non_nullable
              as String?,
      solicitante: freezed == solicitante
          ? _self.solicitante
          : solicitante // ignore: cast_nullable_to_non_nullable
              as ProfissionalSolicitante?,
      procedimentos: null == procedimentos
          ? _self._procedimentos
          : procedimentos // ignore: cast_nullable_to_non_nullable
              as List<Procedimento>,
    ));
  }

  /// Create a copy of GuiaTiss
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ProfissionalSolicitanteCopyWith<$Res>? get solicitante {
    if (_self.solicitante == null) {
      return null;
    }

    return $ProfissionalSolicitanteCopyWith<$Res>(_self.solicitante!, (value) {
      return _then(_self.copyWith(solicitante: value));
    });
  }
}

// dart format on
