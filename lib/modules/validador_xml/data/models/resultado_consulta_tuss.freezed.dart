// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'resultado_consulta_tuss.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ResultadoConsultaTuss {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is ResultadoConsultaTuss);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'ResultadoConsultaTuss()';
  }
}

/// @nodoc
class $ResultadoConsultaTussCopyWith<$Res> {
  $ResultadoConsultaTussCopyWith(
      ResultadoConsultaTuss _, $Res Function(ResultadoConsultaTuss) __);
}

/// Adds pattern-matching-related methods to [ResultadoConsultaTuss].
extension ResultadoConsultaTussPatterns on ResultadoConsultaTuss {
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
  TResult maybeMap<TResult extends Object?>({
    TResult Function(TussEncontrado value)? encontrado,
    TResult Function(TussNaoEncontrado value)? naoEncontrado,
    TResult Function(TussTabelaDivergente value)? tabelaDivergente,
    TResult Function(TussSemReferencia value)? semReferencia,
    TResult Function(TussTabelaDesconhecida value)? tabelaDesconhecida,
    TResult Function(TussIndisponivel value)? indisponivel,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case TussEncontrado() when encontrado != null:
        return encontrado(_that);
      case TussNaoEncontrado() when naoEncontrado != null:
        return naoEncontrado(_that);
      case TussTabelaDivergente() when tabelaDivergente != null:
        return tabelaDivergente(_that);
      case TussSemReferencia() when semReferencia != null:
        return semReferencia(_that);
      case TussTabelaDesconhecida() when tabelaDesconhecida != null:
        return tabelaDesconhecida(_that);
      case TussIndisponivel() when indisponivel != null:
        return indisponivel(_that);
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
  TResult map<TResult extends Object?>({
    required TResult Function(TussEncontrado value) encontrado,
    required TResult Function(TussNaoEncontrado value) naoEncontrado,
    required TResult Function(TussTabelaDivergente value) tabelaDivergente,
    required TResult Function(TussSemReferencia value) semReferencia,
    required TResult Function(TussTabelaDesconhecida value) tabelaDesconhecida,
    required TResult Function(TussIndisponivel value) indisponivel,
  }) {
    final _that = this;
    switch (_that) {
      case TussEncontrado():
        return encontrado(_that);
      case TussNaoEncontrado():
        return naoEncontrado(_that);
      case TussTabelaDivergente():
        return tabelaDivergente(_that);
      case TussSemReferencia():
        return semReferencia(_that);
      case TussTabelaDesconhecida():
        return tabelaDesconhecida(_that);
      case TussIndisponivel():
        return indisponivel(_that);
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
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(TussEncontrado value)? encontrado,
    TResult? Function(TussNaoEncontrado value)? naoEncontrado,
    TResult? Function(TussTabelaDivergente value)? tabelaDivergente,
    TResult? Function(TussSemReferencia value)? semReferencia,
    TResult? Function(TussTabelaDesconhecida value)? tabelaDesconhecida,
    TResult? Function(TussIndisponivel value)? indisponivel,
  }) {
    final _that = this;
    switch (_that) {
      case TussEncontrado() when encontrado != null:
        return encontrado(_that);
      case TussNaoEncontrado() when naoEncontrado != null:
        return naoEncontrado(_that);
      case TussTabelaDivergente() when tabelaDivergente != null:
        return tabelaDivergente(_that);
      case TussSemReferencia() when semReferencia != null:
        return semReferencia(_that);
      case TussTabelaDesconhecida() when tabelaDesconhecida != null:
        return tabelaDesconhecida(_that);
      case TussIndisponivel() when indisponivel != null:
        return indisponivel(_that);
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
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(TussItem item, bool vigente)? encontrado,
    TResult Function(String codigo, String tabela)? naoEncontrado,
    TResult Function(
            String codigo, String tabelaDeclarada, String tabelaEncontrada)?
        tabelaDivergente,
    TResult Function(String codigo, String tabela)? semReferencia,
    TResult Function(String codigo, String tabela)? tabelaDesconhecida,
    TResult Function(String codigo, String tabela, String motivo)? indisponivel,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case TussEncontrado() when encontrado != null:
        return encontrado(_that.item, _that.vigente);
      case TussNaoEncontrado() when naoEncontrado != null:
        return naoEncontrado(_that.codigo, _that.tabela);
      case TussTabelaDivergente() when tabelaDivergente != null:
        return tabelaDivergente(
            _that.codigo, _that.tabelaDeclarada, _that.tabelaEncontrada);
      case TussSemReferencia() when semReferencia != null:
        return semReferencia(_that.codigo, _that.tabela);
      case TussTabelaDesconhecida() when tabelaDesconhecida != null:
        return tabelaDesconhecida(_that.codigo, _that.tabela);
      case TussIndisponivel() when indisponivel != null:
        return indisponivel(_that.codigo, _that.tabela, _that.motivo);
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
  TResult when<TResult extends Object?>({
    required TResult Function(TussItem item, bool vigente) encontrado,
    required TResult Function(String codigo, String tabela) naoEncontrado,
    required TResult Function(
            String codigo, String tabelaDeclarada, String tabelaEncontrada)
        tabelaDivergente,
    required TResult Function(String codigo, String tabela) semReferencia,
    required TResult Function(String codigo, String tabela) tabelaDesconhecida,
    required TResult Function(String codigo, String tabela, String motivo)
        indisponivel,
  }) {
    final _that = this;
    switch (_that) {
      case TussEncontrado():
        return encontrado(_that.item, _that.vigente);
      case TussNaoEncontrado():
        return naoEncontrado(_that.codigo, _that.tabela);
      case TussTabelaDivergente():
        return tabelaDivergente(
            _that.codigo, _that.tabelaDeclarada, _that.tabelaEncontrada);
      case TussSemReferencia():
        return semReferencia(_that.codigo, _that.tabela);
      case TussTabelaDesconhecida():
        return tabelaDesconhecida(_that.codigo, _that.tabela);
      case TussIndisponivel():
        return indisponivel(_that.codigo, _that.tabela, _that.motivo);
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
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(TussItem item, bool vigente)? encontrado,
    TResult? Function(String codigo, String tabela)? naoEncontrado,
    TResult? Function(
            String codigo, String tabelaDeclarada, String tabelaEncontrada)?
        tabelaDivergente,
    TResult? Function(String codigo, String tabela)? semReferencia,
    TResult? Function(String codigo, String tabela)? tabelaDesconhecida,
    TResult? Function(String codigo, String tabela, String motivo)?
        indisponivel,
  }) {
    final _that = this;
    switch (_that) {
      case TussEncontrado() when encontrado != null:
        return encontrado(_that.item, _that.vigente);
      case TussNaoEncontrado() when naoEncontrado != null:
        return naoEncontrado(_that.codigo, _that.tabela);
      case TussTabelaDivergente() when tabelaDivergente != null:
        return tabelaDivergente(
            _that.codigo, _that.tabelaDeclarada, _that.tabelaEncontrada);
      case TussSemReferencia() when semReferencia != null:
        return semReferencia(_that.codigo, _that.tabela);
      case TussTabelaDesconhecida() when tabelaDesconhecida != null:
        return tabelaDesconhecida(_that.codigo, _that.tabela);
      case TussIndisponivel() when indisponivel != null:
        return indisponivel(_that.codigo, _that.tabela, _that.motivo);
      case _:
        return null;
    }
  }
}

/// @nodoc

class TussEncontrado implements ResultadoConsultaTuss {
  const TussEncontrado({required this.item, required this.vigente});

  final TussItem item;
  final bool vigente;

  /// Create a copy of ResultadoConsultaTuss
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TussEncontradoCopyWith<TussEncontrado> get copyWith =>
      _$TussEncontradoCopyWithImpl<TussEncontrado>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TussEncontrado &&
            (identical(other.item, item) || other.item == item) &&
            (identical(other.vigente, vigente) || other.vigente == vigente));
  }

  @override
  int get hashCode => Object.hash(runtimeType, item, vigente);

  @override
  String toString() {
    return 'ResultadoConsultaTuss.encontrado(item: $item, vigente: $vigente)';
  }
}

/// @nodoc
abstract mixin class $TussEncontradoCopyWith<$Res>
    implements $ResultadoConsultaTussCopyWith<$Res> {
  factory $TussEncontradoCopyWith(
          TussEncontrado value, $Res Function(TussEncontrado) _then) =
      _$TussEncontradoCopyWithImpl;
  @useResult
  $Res call({TussItem item, bool vigente});

  $TussItemCopyWith<$Res> get item;
}

/// @nodoc
class _$TussEncontradoCopyWithImpl<$Res>
    implements $TussEncontradoCopyWith<$Res> {
  _$TussEncontradoCopyWithImpl(this._self, this._then);

  final TussEncontrado _self;
  final $Res Function(TussEncontrado) _then;

  /// Create a copy of ResultadoConsultaTuss
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? item = null,
    Object? vigente = null,
  }) {
    return _then(TussEncontrado(
      item: null == item
          ? _self.item
          : item // ignore: cast_nullable_to_non_nullable
              as TussItem,
      vigente: null == vigente
          ? _self.vigente
          : vigente // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }

  /// Create a copy of ResultadoConsultaTuss
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TussItemCopyWith<$Res> get item {
    return $TussItemCopyWith<$Res>(_self.item, (value) {
      return _then(_self.copyWith(item: value));
    });
  }
}

/// @nodoc

class TussNaoEncontrado implements ResultadoConsultaTuss {
  const TussNaoEncontrado({required this.codigo, required this.tabela});

  final String codigo;
  final String tabela;

  /// Create a copy of ResultadoConsultaTuss
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TussNaoEncontradoCopyWith<TussNaoEncontrado> get copyWith =>
      _$TussNaoEncontradoCopyWithImpl<TussNaoEncontrado>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TussNaoEncontrado &&
            (identical(other.codigo, codigo) || other.codigo == codigo) &&
            (identical(other.tabela, tabela) || other.tabela == tabela));
  }

  @override
  int get hashCode => Object.hash(runtimeType, codigo, tabela);

  @override
  String toString() {
    return 'ResultadoConsultaTuss.naoEncontrado(codigo: $codigo, tabela: $tabela)';
  }
}

/// @nodoc
abstract mixin class $TussNaoEncontradoCopyWith<$Res>
    implements $ResultadoConsultaTussCopyWith<$Res> {
  factory $TussNaoEncontradoCopyWith(
          TussNaoEncontrado value, $Res Function(TussNaoEncontrado) _then) =
      _$TussNaoEncontradoCopyWithImpl;
  @useResult
  $Res call({String codigo, String tabela});
}

/// @nodoc
class _$TussNaoEncontradoCopyWithImpl<$Res>
    implements $TussNaoEncontradoCopyWith<$Res> {
  _$TussNaoEncontradoCopyWithImpl(this._self, this._then);

  final TussNaoEncontrado _self;
  final $Res Function(TussNaoEncontrado) _then;

  /// Create a copy of ResultadoConsultaTuss
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? codigo = null,
    Object? tabela = null,
  }) {
    return _then(TussNaoEncontrado(
      codigo: null == codigo
          ? _self.codigo
          : codigo // ignore: cast_nullable_to_non_nullable
              as String,
      tabela: null == tabela
          ? _self.tabela
          : tabela // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class TussTabelaDivergente implements ResultadoConsultaTuss {
  const TussTabelaDivergente(
      {required this.codigo,
      required this.tabelaDeclarada,
      required this.tabelaEncontrada});

  final String codigo;
  final String tabelaDeclarada;
  final String tabelaEncontrada;

  /// Create a copy of ResultadoConsultaTuss
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TussTabelaDivergenteCopyWith<TussTabelaDivergente> get copyWith =>
      _$TussTabelaDivergenteCopyWithImpl<TussTabelaDivergente>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TussTabelaDivergente &&
            (identical(other.codigo, codigo) || other.codigo == codigo) &&
            (identical(other.tabelaDeclarada, tabelaDeclarada) ||
                other.tabelaDeclarada == tabelaDeclarada) &&
            (identical(other.tabelaEncontrada, tabelaEncontrada) ||
                other.tabelaEncontrada == tabelaEncontrada));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, codigo, tabelaDeclarada, tabelaEncontrada);

  @override
  String toString() {
    return 'ResultadoConsultaTuss.tabelaDivergente(codigo: $codigo, tabelaDeclarada: $tabelaDeclarada, tabelaEncontrada: $tabelaEncontrada)';
  }
}

/// @nodoc
abstract mixin class $TussTabelaDivergenteCopyWith<$Res>
    implements $ResultadoConsultaTussCopyWith<$Res> {
  factory $TussTabelaDivergenteCopyWith(TussTabelaDivergente value,
          $Res Function(TussTabelaDivergente) _then) =
      _$TussTabelaDivergenteCopyWithImpl;
  @useResult
  $Res call({String codigo, String tabelaDeclarada, String tabelaEncontrada});
}

/// @nodoc
class _$TussTabelaDivergenteCopyWithImpl<$Res>
    implements $TussTabelaDivergenteCopyWith<$Res> {
  _$TussTabelaDivergenteCopyWithImpl(this._self, this._then);

  final TussTabelaDivergente _self;
  final $Res Function(TussTabelaDivergente) _then;

  /// Create a copy of ResultadoConsultaTuss
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? codigo = null,
    Object? tabelaDeclarada = null,
    Object? tabelaEncontrada = null,
  }) {
    return _then(TussTabelaDivergente(
      codigo: null == codigo
          ? _self.codigo
          : codigo // ignore: cast_nullable_to_non_nullable
              as String,
      tabelaDeclarada: null == tabelaDeclarada
          ? _self.tabelaDeclarada
          : tabelaDeclarada // ignore: cast_nullable_to_non_nullable
              as String,
      tabelaEncontrada: null == tabelaEncontrada
          ? _self.tabelaEncontrada
          : tabelaEncontrada // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class TussSemReferencia implements ResultadoConsultaTuss {
  const TussSemReferencia({required this.codigo, required this.tabela});

  final String codigo;
  final String tabela;

  /// Create a copy of ResultadoConsultaTuss
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TussSemReferenciaCopyWith<TussSemReferencia> get copyWith =>
      _$TussSemReferenciaCopyWithImpl<TussSemReferencia>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TussSemReferencia &&
            (identical(other.codigo, codigo) || other.codigo == codigo) &&
            (identical(other.tabela, tabela) || other.tabela == tabela));
  }

  @override
  int get hashCode => Object.hash(runtimeType, codigo, tabela);

  @override
  String toString() {
    return 'ResultadoConsultaTuss.semReferencia(codigo: $codigo, tabela: $tabela)';
  }
}

/// @nodoc
abstract mixin class $TussSemReferenciaCopyWith<$Res>
    implements $ResultadoConsultaTussCopyWith<$Res> {
  factory $TussSemReferenciaCopyWith(
          TussSemReferencia value, $Res Function(TussSemReferencia) _then) =
      _$TussSemReferenciaCopyWithImpl;
  @useResult
  $Res call({String codigo, String tabela});
}

/// @nodoc
class _$TussSemReferenciaCopyWithImpl<$Res>
    implements $TussSemReferenciaCopyWith<$Res> {
  _$TussSemReferenciaCopyWithImpl(this._self, this._then);

  final TussSemReferencia _self;
  final $Res Function(TussSemReferencia) _then;

  /// Create a copy of ResultadoConsultaTuss
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? codigo = null,
    Object? tabela = null,
  }) {
    return _then(TussSemReferencia(
      codigo: null == codigo
          ? _self.codigo
          : codigo // ignore: cast_nullable_to_non_nullable
              as String,
      tabela: null == tabela
          ? _self.tabela
          : tabela // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class TussTabelaDesconhecida implements ResultadoConsultaTuss {
  const TussTabelaDesconhecida({required this.codigo, required this.tabela});

  final String codigo;
  final String tabela;

  /// Create a copy of ResultadoConsultaTuss
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TussTabelaDesconhecidaCopyWith<TussTabelaDesconhecida> get copyWith =>
      _$TussTabelaDesconhecidaCopyWithImpl<TussTabelaDesconhecida>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TussTabelaDesconhecida &&
            (identical(other.codigo, codigo) || other.codigo == codigo) &&
            (identical(other.tabela, tabela) || other.tabela == tabela));
  }

  @override
  int get hashCode => Object.hash(runtimeType, codigo, tabela);

  @override
  String toString() {
    return 'ResultadoConsultaTuss.tabelaDesconhecida(codigo: $codigo, tabela: $tabela)';
  }
}

/// @nodoc
abstract mixin class $TussTabelaDesconhecidaCopyWith<$Res>
    implements $ResultadoConsultaTussCopyWith<$Res> {
  factory $TussTabelaDesconhecidaCopyWith(TussTabelaDesconhecida value,
          $Res Function(TussTabelaDesconhecida) _then) =
      _$TussTabelaDesconhecidaCopyWithImpl;
  @useResult
  $Res call({String codigo, String tabela});
}

/// @nodoc
class _$TussTabelaDesconhecidaCopyWithImpl<$Res>
    implements $TussTabelaDesconhecidaCopyWith<$Res> {
  _$TussTabelaDesconhecidaCopyWithImpl(this._self, this._then);

  final TussTabelaDesconhecida _self;
  final $Res Function(TussTabelaDesconhecida) _then;

  /// Create a copy of ResultadoConsultaTuss
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? codigo = null,
    Object? tabela = null,
  }) {
    return _then(TussTabelaDesconhecida(
      codigo: null == codigo
          ? _self.codigo
          : codigo // ignore: cast_nullable_to_non_nullable
              as String,
      tabela: null == tabela
          ? _self.tabela
          : tabela // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class TussIndisponivel implements ResultadoConsultaTuss {
  const TussIndisponivel(
      {required this.codigo, required this.tabela, required this.motivo});

  final String codigo;
  final String tabela;
  final String motivo;

  /// Create a copy of ResultadoConsultaTuss
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TussIndisponivelCopyWith<TussIndisponivel> get copyWith =>
      _$TussIndisponivelCopyWithImpl<TussIndisponivel>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TussIndisponivel &&
            (identical(other.codigo, codigo) || other.codigo == codigo) &&
            (identical(other.tabela, tabela) || other.tabela == tabela) &&
            (identical(other.motivo, motivo) || other.motivo == motivo));
  }

  @override
  int get hashCode => Object.hash(runtimeType, codigo, tabela, motivo);

  @override
  String toString() {
    return 'ResultadoConsultaTuss.indisponivel(codigo: $codigo, tabela: $tabela, motivo: $motivo)';
  }
}

/// @nodoc
abstract mixin class $TussIndisponivelCopyWith<$Res>
    implements $ResultadoConsultaTussCopyWith<$Res> {
  factory $TussIndisponivelCopyWith(
          TussIndisponivel value, $Res Function(TussIndisponivel) _then) =
      _$TussIndisponivelCopyWithImpl;
  @useResult
  $Res call({String codigo, String tabela, String motivo});
}

/// @nodoc
class _$TussIndisponivelCopyWithImpl<$Res>
    implements $TussIndisponivelCopyWith<$Res> {
  _$TussIndisponivelCopyWithImpl(this._self, this._then);

  final TussIndisponivel _self;
  final $Res Function(TussIndisponivel) _then;

  /// Create a copy of ResultadoConsultaTuss
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? codigo = null,
    Object? tabela = null,
    Object? motivo = null,
  }) {
    return _then(TussIndisponivel(
      codigo: null == codigo
          ? _self.codigo
          : codigo // ignore: cast_nullable_to_non_nullable
              as String,
      tabela: null == tabela
          ? _self.tabela
          : tabela // ignore: cast_nullable_to_non_nullable
              as String,
      motivo: null == motivo
          ? _self.motivo
          : motivo // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
