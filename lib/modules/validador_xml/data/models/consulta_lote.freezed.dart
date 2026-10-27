// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'consulta_lote.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ConsultaLoteItem {
  TipoConsultaGuia get tipo;
  String get chave;

  /// Create a copy of ConsultaLoteItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ConsultaLoteItemCopyWith<ConsultaLoteItem> get copyWith =>
      _$ConsultaLoteItemCopyWithImpl<ConsultaLoteItem>(
          this as ConsultaLoteItem, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ConsultaLoteItem &&
            (identical(other.tipo, tipo) || other.tipo == tipo) &&
            (identical(other.chave, chave) || other.chave == chave));
  }

  @override
  int get hashCode => Object.hash(runtimeType, tipo, chave);

  @override
  String toString() {
    return 'ConsultaLoteItem(tipo: $tipo, chave: $chave)';
  }
}

/// @nodoc
abstract mixin class $ConsultaLoteItemCopyWith<$Res> {
  factory $ConsultaLoteItemCopyWith(
          ConsultaLoteItem value, $Res Function(ConsultaLoteItem) _then) =
      _$ConsultaLoteItemCopyWithImpl;
  @useResult
  $Res call({TipoConsultaGuia tipo, String chave});
}

/// @nodoc
class _$ConsultaLoteItemCopyWithImpl<$Res>
    implements $ConsultaLoteItemCopyWith<$Res> {
  _$ConsultaLoteItemCopyWithImpl(this._self, this._then);

  final ConsultaLoteItem _self;
  final $Res Function(ConsultaLoteItem) _then;

  /// Create a copy of ConsultaLoteItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tipo = null,
    Object? chave = null,
  }) {
    return _then(_self.copyWith(
      tipo: null == tipo
          ? _self.tipo
          : tipo // ignore: cast_nullable_to_non_nullable
              as TipoConsultaGuia,
      chave: null == chave
          ? _self.chave
          : chave // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [ConsultaLoteItem].
extension ConsultaLoteItemPatterns on ConsultaLoteItem {
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
    TResult Function(_ConsultaLoteItem value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ConsultaLoteItem() when $default != null:
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
    TResult Function(_ConsultaLoteItem value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ConsultaLoteItem():
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
    TResult? Function(_ConsultaLoteItem value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ConsultaLoteItem() when $default != null:
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
    TResult Function(TipoConsultaGuia tipo, String chave)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ConsultaLoteItem() when $default != null:
        return $default(_that.tipo, _that.chave);
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
    TResult Function(TipoConsultaGuia tipo, String chave) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ConsultaLoteItem():
        return $default(_that.tipo, _that.chave);
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
    TResult? Function(TipoConsultaGuia tipo, String chave)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ConsultaLoteItem() when $default != null:
        return $default(_that.tipo, _that.chave);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ConsultaLoteItem implements ConsultaLoteItem {
  const _ConsultaLoteItem({required this.tipo, required this.chave});

  @override
  final TipoConsultaGuia tipo;
  @override
  final String chave;

  /// Create a copy of ConsultaLoteItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ConsultaLoteItemCopyWith<_ConsultaLoteItem> get copyWith =>
      __$ConsultaLoteItemCopyWithImpl<_ConsultaLoteItem>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ConsultaLoteItem &&
            (identical(other.tipo, tipo) || other.tipo == tipo) &&
            (identical(other.chave, chave) || other.chave == chave));
  }

  @override
  int get hashCode => Object.hash(runtimeType, tipo, chave);

  @override
  String toString() {
    return 'ConsultaLoteItem(tipo: $tipo, chave: $chave)';
  }
}

/// @nodoc
abstract mixin class _$ConsultaLoteItemCopyWith<$Res>
    implements $ConsultaLoteItemCopyWith<$Res> {
  factory _$ConsultaLoteItemCopyWith(
          _ConsultaLoteItem value, $Res Function(_ConsultaLoteItem) _then) =
      __$ConsultaLoteItemCopyWithImpl;
  @override
  @useResult
  $Res call({TipoConsultaGuia tipo, String chave});
}

/// @nodoc
class __$ConsultaLoteItemCopyWithImpl<$Res>
    implements _$ConsultaLoteItemCopyWith<$Res> {
  __$ConsultaLoteItemCopyWithImpl(this._self, this._then);

  final _ConsultaLoteItem _self;
  final $Res Function(_ConsultaLoteItem) _then;

  /// Create a copy of ConsultaLoteItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? tipo = null,
    Object? chave = null,
  }) {
    return _then(_ConsultaLoteItem(
      tipo: null == tipo
          ? _self.tipo
          : tipo // ignore: cast_nullable_to_non_nullable
              as TipoConsultaGuia,
      chave: null == chave
          ? _self.chave
          : chave // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$ResultadoConsultaLote {
  String get chave;
  TipoConsultaGuia get tipo;
  bool get sucesso;
  bool? get elegivel;
  String? get rotuloElegibilidade;
  String? get statusSenha;
  String? get erro;

  /// Create a copy of ResultadoConsultaLote
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ResultadoConsultaLoteCopyWith<ResultadoConsultaLote> get copyWith =>
      _$ResultadoConsultaLoteCopyWithImpl<ResultadoConsultaLote>(
          this as ResultadoConsultaLote, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ResultadoConsultaLote &&
            (identical(other.chave, chave) || other.chave == chave) &&
            (identical(other.tipo, tipo) || other.tipo == tipo) &&
            (identical(other.sucesso, sucesso) || other.sucesso == sucesso) &&
            (identical(other.elegivel, elegivel) ||
                other.elegivel == elegivel) &&
            (identical(other.rotuloElegibilidade, rotuloElegibilidade) ||
                other.rotuloElegibilidade == rotuloElegibilidade) &&
            (identical(other.statusSenha, statusSenha) ||
                other.statusSenha == statusSenha) &&
            (identical(other.erro, erro) || other.erro == erro));
  }

  @override
  int get hashCode => Object.hash(runtimeType, chave, tipo, sucesso, elegivel,
      rotuloElegibilidade, statusSenha, erro);

  @override
  String toString() {
    return 'ResultadoConsultaLote(chave: $chave, tipo: $tipo, sucesso: $sucesso, elegivel: $elegivel, rotuloElegibilidade: $rotuloElegibilidade, statusSenha: $statusSenha, erro: $erro)';
  }
}

/// @nodoc
abstract mixin class $ResultadoConsultaLoteCopyWith<$Res> {
  factory $ResultadoConsultaLoteCopyWith(ResultadoConsultaLote value,
          $Res Function(ResultadoConsultaLote) _then) =
      _$ResultadoConsultaLoteCopyWithImpl;
  @useResult
  $Res call(
      {String chave,
      TipoConsultaGuia tipo,
      bool sucesso,
      bool? elegivel,
      String? rotuloElegibilidade,
      String? statusSenha,
      String? erro});
}

/// @nodoc
class _$ResultadoConsultaLoteCopyWithImpl<$Res>
    implements $ResultadoConsultaLoteCopyWith<$Res> {
  _$ResultadoConsultaLoteCopyWithImpl(this._self, this._then);

  final ResultadoConsultaLote _self;
  final $Res Function(ResultadoConsultaLote) _then;

  /// Create a copy of ResultadoConsultaLote
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chave = null,
    Object? tipo = null,
    Object? sucesso = null,
    Object? elegivel = freezed,
    Object? rotuloElegibilidade = freezed,
    Object? statusSenha = freezed,
    Object? erro = freezed,
  }) {
    return _then(_self.copyWith(
      chave: null == chave
          ? _self.chave
          : chave // ignore: cast_nullable_to_non_nullable
              as String,
      tipo: null == tipo
          ? _self.tipo
          : tipo // ignore: cast_nullable_to_non_nullable
              as TipoConsultaGuia,
      sucesso: null == sucesso
          ? _self.sucesso
          : sucesso // ignore: cast_nullable_to_non_nullable
              as bool,
      elegivel: freezed == elegivel
          ? _self.elegivel
          : elegivel // ignore: cast_nullable_to_non_nullable
              as bool?,
      rotuloElegibilidade: freezed == rotuloElegibilidade
          ? _self.rotuloElegibilidade
          : rotuloElegibilidade // ignore: cast_nullable_to_non_nullable
              as String?,
      statusSenha: freezed == statusSenha
          ? _self.statusSenha
          : statusSenha // ignore: cast_nullable_to_non_nullable
              as String?,
      erro: freezed == erro
          ? _self.erro
          : erro // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [ResultadoConsultaLote].
extension ResultadoConsultaLotePatterns on ResultadoConsultaLote {
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
    TResult Function(_ResultadoConsultaLote value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ResultadoConsultaLote() when $default != null:
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
    TResult Function(_ResultadoConsultaLote value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ResultadoConsultaLote():
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
    TResult? Function(_ResultadoConsultaLote value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ResultadoConsultaLote() when $default != null:
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
            String chave,
            TipoConsultaGuia tipo,
            bool sucesso,
            bool? elegivel,
            String? rotuloElegibilidade,
            String? statusSenha,
            String? erro)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ResultadoConsultaLote() when $default != null:
        return $default(_that.chave, _that.tipo, _that.sucesso, _that.elegivel,
            _that.rotuloElegibilidade, _that.statusSenha, _that.erro);
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
            String chave,
            TipoConsultaGuia tipo,
            bool sucesso,
            bool? elegivel,
            String? rotuloElegibilidade,
            String? statusSenha,
            String? erro)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ResultadoConsultaLote():
        return $default(_that.chave, _that.tipo, _that.sucesso, _that.elegivel,
            _that.rotuloElegibilidade, _that.statusSenha, _that.erro);
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
            String chave,
            TipoConsultaGuia tipo,
            bool sucesso,
            bool? elegivel,
            String? rotuloElegibilidade,
            String? statusSenha,
            String? erro)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ResultadoConsultaLote() when $default != null:
        return $default(_that.chave, _that.tipo, _that.sucesso, _that.elegivel,
            _that.rotuloElegibilidade, _that.statusSenha, _that.erro);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ResultadoConsultaLote implements ResultadoConsultaLote {
  const _ResultadoConsultaLote(
      {required this.chave,
      required this.tipo,
      required this.sucesso,
      this.elegivel,
      this.rotuloElegibilidade,
      this.statusSenha,
      this.erro});

  @override
  final String chave;
  @override
  final TipoConsultaGuia tipo;
  @override
  final bool sucesso;
  @override
  final bool? elegivel;
  @override
  final String? rotuloElegibilidade;
  @override
  final String? statusSenha;
  @override
  final String? erro;

  /// Create a copy of ResultadoConsultaLote
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ResultadoConsultaLoteCopyWith<_ResultadoConsultaLote> get copyWith =>
      __$ResultadoConsultaLoteCopyWithImpl<_ResultadoConsultaLote>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ResultadoConsultaLote &&
            (identical(other.chave, chave) || other.chave == chave) &&
            (identical(other.tipo, tipo) || other.tipo == tipo) &&
            (identical(other.sucesso, sucesso) || other.sucesso == sucesso) &&
            (identical(other.elegivel, elegivel) ||
                other.elegivel == elegivel) &&
            (identical(other.rotuloElegibilidade, rotuloElegibilidade) ||
                other.rotuloElegibilidade == rotuloElegibilidade) &&
            (identical(other.statusSenha, statusSenha) ||
                other.statusSenha == statusSenha) &&
            (identical(other.erro, erro) || other.erro == erro));
  }

  @override
  int get hashCode => Object.hash(runtimeType, chave, tipo, sucesso, elegivel,
      rotuloElegibilidade, statusSenha, erro);

  @override
  String toString() {
    return 'ResultadoConsultaLote(chave: $chave, tipo: $tipo, sucesso: $sucesso, elegivel: $elegivel, rotuloElegibilidade: $rotuloElegibilidade, statusSenha: $statusSenha, erro: $erro)';
  }
}

/// @nodoc
abstract mixin class _$ResultadoConsultaLoteCopyWith<$Res>
    implements $ResultadoConsultaLoteCopyWith<$Res> {
  factory _$ResultadoConsultaLoteCopyWith(_ResultadoConsultaLote value,
          $Res Function(_ResultadoConsultaLote) _then) =
      __$ResultadoConsultaLoteCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String chave,
      TipoConsultaGuia tipo,
      bool sucesso,
      bool? elegivel,
      String? rotuloElegibilidade,
      String? statusSenha,
      String? erro});
}

/// @nodoc
class __$ResultadoConsultaLoteCopyWithImpl<$Res>
    implements _$ResultadoConsultaLoteCopyWith<$Res> {
  __$ResultadoConsultaLoteCopyWithImpl(this._self, this._then);

  final _ResultadoConsultaLote _self;
  final $Res Function(_ResultadoConsultaLote) _then;

  /// Create a copy of ResultadoConsultaLote
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? chave = null,
    Object? tipo = null,
    Object? sucesso = null,
    Object? elegivel = freezed,
    Object? rotuloElegibilidade = freezed,
    Object? statusSenha = freezed,
    Object? erro = freezed,
  }) {
    return _then(_ResultadoConsultaLote(
      chave: null == chave
          ? _self.chave
          : chave // ignore: cast_nullable_to_non_nullable
              as String,
      tipo: null == tipo
          ? _self.tipo
          : tipo // ignore: cast_nullable_to_non_nullable
              as TipoConsultaGuia,
      sucesso: null == sucesso
          ? _self.sucesso
          : sucesso // ignore: cast_nullable_to_non_nullable
              as bool,
      elegivel: freezed == elegivel
          ? _self.elegivel
          : elegivel // ignore: cast_nullable_to_non_nullable
              as bool?,
      rotuloElegibilidade: freezed == rotuloElegibilidade
          ? _self.rotuloElegibilidade
          : rotuloElegibilidade // ignore: cast_nullable_to_non_nullable
              as String?,
      statusSenha: freezed == statusSenha
          ? _self.statusSenha
          : statusSenha // ignore: cast_nullable_to_non_nullable
              as String?,
      erro: freezed == erro
          ? _self.erro
          : erro // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
