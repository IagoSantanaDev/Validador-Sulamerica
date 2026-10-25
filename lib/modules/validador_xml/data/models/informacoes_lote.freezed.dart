// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'informacoes_lote.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$InformacoesLote {
  String? get versao;
  String? get tipoTransacao;
  String? get hash;
  String? get prestadorCnpjCpf;
  String? get operadoraRegistroANS;
  String? get numeroLote;
  int? get qtdGuias;
  String? get valorTotalInformado;

  /// Create a copy of InformacoesLote
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $InformacoesLoteCopyWith<InformacoesLote> get copyWith =>
      _$InformacoesLoteCopyWithImpl<InformacoesLote>(
          this as InformacoesLote, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is InformacoesLote &&
            (identical(other.versao, versao) || other.versao == versao) &&
            (identical(other.tipoTransacao, tipoTransacao) ||
                other.tipoTransacao == tipoTransacao) &&
            (identical(other.hash, hash) || other.hash == hash) &&
            (identical(other.prestadorCnpjCpf, prestadorCnpjCpf) ||
                other.prestadorCnpjCpf == prestadorCnpjCpf) &&
            (identical(other.operadoraRegistroANS, operadoraRegistroANS) ||
                other.operadoraRegistroANS == operadoraRegistroANS) &&
            (identical(other.numeroLote, numeroLote) ||
                other.numeroLote == numeroLote) &&
            (identical(other.qtdGuias, qtdGuias) ||
                other.qtdGuias == qtdGuias) &&
            (identical(other.valorTotalInformado, valorTotalInformado) ||
                other.valorTotalInformado == valorTotalInformado));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      versao,
      tipoTransacao,
      hash,
      prestadorCnpjCpf,
      operadoraRegistroANS,
      numeroLote,
      qtdGuias,
      valorTotalInformado);

  @override
  String toString() {
    return 'InformacoesLote(versao: $versao, tipoTransacao: $tipoTransacao, hash: $hash, prestadorCnpjCpf: $prestadorCnpjCpf, operadoraRegistroANS: $operadoraRegistroANS, numeroLote: $numeroLote, qtdGuias: $qtdGuias, valorTotalInformado: $valorTotalInformado)';
  }
}

/// @nodoc
abstract mixin class $InformacoesLoteCopyWith<$Res> {
  factory $InformacoesLoteCopyWith(
          InformacoesLote value, $Res Function(InformacoesLote) _then) =
      _$InformacoesLoteCopyWithImpl;
  @useResult
  $Res call(
      {String? versao,
      String? tipoTransacao,
      String? hash,
      String? prestadorCnpjCpf,
      String? operadoraRegistroANS,
      String? numeroLote,
      int? qtdGuias,
      String? valorTotalInformado});
}

/// @nodoc
class _$InformacoesLoteCopyWithImpl<$Res>
    implements $InformacoesLoteCopyWith<$Res> {
  _$InformacoesLoteCopyWithImpl(this._self, this._then);

  final InformacoesLote _self;
  final $Res Function(InformacoesLote) _then;

  /// Create a copy of InformacoesLote
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? versao = freezed,
    Object? tipoTransacao = freezed,
    Object? hash = freezed,
    Object? prestadorCnpjCpf = freezed,
    Object? operadoraRegistroANS = freezed,
    Object? numeroLote = freezed,
    Object? qtdGuias = freezed,
    Object? valorTotalInformado = freezed,
  }) {
    return _then(_self.copyWith(
      versao: freezed == versao
          ? _self.versao
          : versao // ignore: cast_nullable_to_non_nullable
              as String?,
      tipoTransacao: freezed == tipoTransacao
          ? _self.tipoTransacao
          : tipoTransacao // ignore: cast_nullable_to_non_nullable
              as String?,
      hash: freezed == hash
          ? _self.hash
          : hash // ignore: cast_nullable_to_non_nullable
              as String?,
      prestadorCnpjCpf: freezed == prestadorCnpjCpf
          ? _self.prestadorCnpjCpf
          : prestadorCnpjCpf // ignore: cast_nullable_to_non_nullable
              as String?,
      operadoraRegistroANS: freezed == operadoraRegistroANS
          ? _self.operadoraRegistroANS
          : operadoraRegistroANS // ignore: cast_nullable_to_non_nullable
              as String?,
      numeroLote: freezed == numeroLote
          ? _self.numeroLote
          : numeroLote // ignore: cast_nullable_to_non_nullable
              as String?,
      qtdGuias: freezed == qtdGuias
          ? _self.qtdGuias
          : qtdGuias // ignore: cast_nullable_to_non_nullable
              as int?,
      valorTotalInformado: freezed == valorTotalInformado
          ? _self.valorTotalInformado
          : valorTotalInformado // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [InformacoesLote].
extension InformacoesLotePatterns on InformacoesLote {
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
    TResult Function(_InformacoesLote value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _InformacoesLote() when $default != null:
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
    TResult Function(_InformacoesLote value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _InformacoesLote():
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
    TResult? Function(_InformacoesLote value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _InformacoesLote() when $default != null:
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
            String? versao,
            String? tipoTransacao,
            String? hash,
            String? prestadorCnpjCpf,
            String? operadoraRegistroANS,
            String? numeroLote,
            int? qtdGuias,
            String? valorTotalInformado)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _InformacoesLote() when $default != null:
        return $default(
            _that.versao,
            _that.tipoTransacao,
            _that.hash,
            _that.prestadorCnpjCpf,
            _that.operadoraRegistroANS,
            _that.numeroLote,
            _that.qtdGuias,
            _that.valorTotalInformado);
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
            String? versao,
            String? tipoTransacao,
            String? hash,
            String? prestadorCnpjCpf,
            String? operadoraRegistroANS,
            String? numeroLote,
            int? qtdGuias,
            String? valorTotalInformado)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _InformacoesLote():
        return $default(
            _that.versao,
            _that.tipoTransacao,
            _that.hash,
            _that.prestadorCnpjCpf,
            _that.operadoraRegistroANS,
            _that.numeroLote,
            _that.qtdGuias,
            _that.valorTotalInformado);
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
            String? versao,
            String? tipoTransacao,
            String? hash,
            String? prestadorCnpjCpf,
            String? operadoraRegistroANS,
            String? numeroLote,
            int? qtdGuias,
            String? valorTotalInformado)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _InformacoesLote() when $default != null:
        return $default(
            _that.versao,
            _that.tipoTransacao,
            _that.hash,
            _that.prestadorCnpjCpf,
            _that.operadoraRegistroANS,
            _that.numeroLote,
            _that.qtdGuias,
            _that.valorTotalInformado);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _InformacoesLote implements InformacoesLote {
  const _InformacoesLote(
      {this.versao,
      this.tipoTransacao,
      this.hash,
      this.prestadorCnpjCpf,
      this.operadoraRegistroANS,
      this.numeroLote,
      this.qtdGuias,
      this.valorTotalInformado});

  @override
  final String? versao;
  @override
  final String? tipoTransacao;
  @override
  final String? hash;
  @override
  final String? prestadorCnpjCpf;
  @override
  final String? operadoraRegistroANS;
  @override
  final String? numeroLote;
  @override
  final int? qtdGuias;
  @override
  final String? valorTotalInformado;

  /// Create a copy of InformacoesLote
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$InformacoesLoteCopyWith<_InformacoesLote> get copyWith =>
      __$InformacoesLoteCopyWithImpl<_InformacoesLote>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _InformacoesLote &&
            (identical(other.versao, versao) || other.versao == versao) &&
            (identical(other.tipoTransacao, tipoTransacao) ||
                other.tipoTransacao == tipoTransacao) &&
            (identical(other.hash, hash) || other.hash == hash) &&
            (identical(other.prestadorCnpjCpf, prestadorCnpjCpf) ||
                other.prestadorCnpjCpf == prestadorCnpjCpf) &&
            (identical(other.operadoraRegistroANS, operadoraRegistroANS) ||
                other.operadoraRegistroANS == operadoraRegistroANS) &&
            (identical(other.numeroLote, numeroLote) ||
                other.numeroLote == numeroLote) &&
            (identical(other.qtdGuias, qtdGuias) ||
                other.qtdGuias == qtdGuias) &&
            (identical(other.valorTotalInformado, valorTotalInformado) ||
                other.valorTotalInformado == valorTotalInformado));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      versao,
      tipoTransacao,
      hash,
      prestadorCnpjCpf,
      operadoraRegistroANS,
      numeroLote,
      qtdGuias,
      valorTotalInformado);

  @override
  String toString() {
    return 'InformacoesLote(versao: $versao, tipoTransacao: $tipoTransacao, hash: $hash, prestadorCnpjCpf: $prestadorCnpjCpf, operadoraRegistroANS: $operadoraRegistroANS, numeroLote: $numeroLote, qtdGuias: $qtdGuias, valorTotalInformado: $valorTotalInformado)';
  }
}

/// @nodoc
abstract mixin class _$InformacoesLoteCopyWith<$Res>
    implements $InformacoesLoteCopyWith<$Res> {
  factory _$InformacoesLoteCopyWith(
          _InformacoesLote value, $Res Function(_InformacoesLote) _then) =
      __$InformacoesLoteCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String? versao,
      String? tipoTransacao,
      String? hash,
      String? prestadorCnpjCpf,
      String? operadoraRegistroANS,
      String? numeroLote,
      int? qtdGuias,
      String? valorTotalInformado});
}

/// @nodoc
class __$InformacoesLoteCopyWithImpl<$Res>
    implements _$InformacoesLoteCopyWith<$Res> {
  __$InformacoesLoteCopyWithImpl(this._self, this._then);

  final _InformacoesLote _self;
  final $Res Function(_InformacoesLote) _then;

  /// Create a copy of InformacoesLote
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? versao = freezed,
    Object? tipoTransacao = freezed,
    Object? hash = freezed,
    Object? prestadorCnpjCpf = freezed,
    Object? operadoraRegistroANS = freezed,
    Object? numeroLote = freezed,
    Object? qtdGuias = freezed,
    Object? valorTotalInformado = freezed,
  }) {
    return _then(_InformacoesLote(
      versao: freezed == versao
          ? _self.versao
          : versao // ignore: cast_nullable_to_non_nullable
              as String?,
      tipoTransacao: freezed == tipoTransacao
          ? _self.tipoTransacao
          : tipoTransacao // ignore: cast_nullable_to_non_nullable
              as String?,
      hash: freezed == hash
          ? _self.hash
          : hash // ignore: cast_nullable_to_non_nullable
              as String?,
      prestadorCnpjCpf: freezed == prestadorCnpjCpf
          ? _self.prestadorCnpjCpf
          : prestadorCnpjCpf // ignore: cast_nullable_to_non_nullable
              as String?,
      operadoraRegistroANS: freezed == operadoraRegistroANS
          ? _self.operadoraRegistroANS
          : operadoraRegistroANS // ignore: cast_nullable_to_non_nullable
              as String?,
      numeroLote: freezed == numeroLote
          ? _self.numeroLote
          : numeroLote // ignore: cast_nullable_to_non_nullable
              as String?,
      qtdGuias: freezed == qtdGuias
          ? _self.qtdGuias
          : qtdGuias // ignore: cast_nullable_to_non_nullable
              as int?,
      valorTotalInformado: freezed == valorTotalInformado
          ? _self.valorTotalInformado
          : valorTotalInformado // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
