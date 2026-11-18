import 'dart:async';

import 'package:dio/dio.dart';

import '../../../../globals/constants/app_strings.dart';
import '../../../../globals/network/app_exception.dart';
import '../../../../globals/network/dio_client.dart';
import '../../../../globals/network/result.dart';
import '../../../../globals/network/sse_client.dart';
import '../models/consulta_lote.dart';
import '../models/lote_remoto.dart';

/// Cliente HTTP do validador. O token de sessão viaja sempre em
/// `Authorization: Bearer`, nunca no corpo nem na URL.
class SulAmericaBackendService {
  SulAmericaBackendService(
    this._dio, {
    this.timeoutHeartbeat = const Duration(seconds: 45),
  });

  final DioClient _dio;
  final Duration timeoutHeartbeat;

  static const String _rotaSessoes = '/api/sessoes';
  static const String _rotaLotes = '/api/lotes';

  Future<Result<String>> criarSessao({required String identificadorPrestador}) {
    return _requisitar<String>(
      metodo: 'POST',
      caminho: _rotaSessoes,
      corpo: {'identificadorPrestador': identificadorPrestador},
      parser: (dynamic dados, Response<dynamic> _) =>
          (dados as Map)['token'] as String,
    );
  }

  Future<Result<LoteRemoto>> criarLote({
    required String token,
    required String idempotencyKey,
    required List<ConsultaLoteItem> consultas,
  }) {
    return _requisitar<LoteRemoto>(
      metodo: 'POST',
      caminho: _rotaLotes,
      cabecalhos: {
        'Authorization': 'Bearer $token',
        'Idempotency-Key': idempotencyKey,
      },
      corpo: {'consultas': _serializarConsultas(consultas)},
      parser: (dynamic dados, Response<dynamic> resposta) {
        return LoteRemoto.fromJson(
          (dados as Map).cast<String, dynamic>(),
          location: resposta.headers.value('location'),
        );
      },
    );
  }

  /// Abre o stream de eventos do lote, retomando de [desde] quando informado.
  ConexaoSse abrirEventos({
    required String token,
    required String idLote,
    int? desde,
  }) {
    final ConexaoSse conexao = abrirEventosSse(
      url: montarUrlEventos(
        _dio.instancia.options.baseUrl,
        idLote,
        desde: desde,
      ),
      token: token,
      ultimoId: desde?.toString(),
      timeoutHeartbeat: timeoutHeartbeat,
    );
    return ConexaoSse(
      conexao.eventos.transform(
        StreamTransformer<EventoSse, EventoSse>.fromHandlers(
          handleError:
              (Object erro, StackTrace pilha, EventSink<EventoSse> sink) {
                sink.addError(_mapearErroStream(erro), pilha);
              },
        ),
      ),
      conexao.cancelar,
    );
  }

  Future<Result<Map<String, dynamic>>> status() {
    return _requisitar<Map<String, dynamic>>(
      metodo: 'GET',
      caminho: '/api/status',
      parser: (dynamic dados, Response<dynamic> _) =>
          (dados as Map).cast<String, dynamic>(),
    );
  }

  static Uri montarUrlEventos(String baseUrl, String idLote, {int? desde}) {
    final String base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final Uri url = Uri.parse(
      '$base$_rotaLotes/${Uri.encodeComponent(idLote)}/eventos',
    );
    return desde == null
        ? url
        : url.replace(queryParameters: {'desde': '$desde'});
  }

  static List<Map<String, String>> _serializarConsultas(
    List<ConsultaLoteItem> consultas,
  ) {
    return [
      for (final ConsultaLoteItem item in consultas)
        {'tipo': item.tipo.name, 'chave': item.chave},
    ];
  }

  Future<Result<T>> _requisitar<T>({
    required String metodo,
    required String caminho,
    required T Function(dynamic dados, Response<dynamic> resposta) parser,
    Object? corpo,
    Map<String, String>? cabecalhos,
    Map<String, dynamic>? parametrosConsulta,
  }) async {
    try {
      final Response<dynamic> resposta = await _dio.instancia.request<dynamic>(
        caminho,
        data: corpo,
        queryParameters: parametrosConsulta,
        options: Options(method: metodo, headers: cabecalhos),
      );
      return Result.success(parser(resposta.data, resposta));
    } on DioException catch (erro) {
      return Result.failure(_mapearErro(erro));
    } on Object {
      return Result.failure<T>(
        const ErroDesconhecidoException(AppStrings.erroConsultaBackendGenerico),
      );
    }
  }

  AppException _mapearErro(DioException erro) {
    return switch (erro.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => const RequisicaoExpiradaException(),
      DioExceptionType.connectionError => const SemConexaoException(),
      DioExceptionType.cancel => const RequisicaoCanceladaException(),
      DioExceptionType.badResponse => _mapearResposta(erro.response),
      DioExceptionType.badCertificate || DioExceptionType.unknown =>
        const ErroDesconhecidoException(AppStrings.erroConsultaBackendGenerico),
    };
  }

  AppException _mapearResposta(Response<dynamic>? resposta) {
    return _mapearStatus(
      resposta?.statusCode,
      mensagem: _mensagemDoCorpo(resposta?.data),
      retryAfter: _retryAfter(resposta),
    );
  }

  AppException _mapearStatus(
    int? statusCode, {
    String? mensagem,
    Duration? retryAfter,
  }) {
    if (statusCode == 401 || statusCode == 403) {
      return const NaoAutorizadoException();
    }
    if (statusCode == 404) {
      return const RecursoNaoEncontradoException();
    }
    if (statusCode == 429) {
      return FilaCheiaException(retryAfter: retryAfter, mensagem: mensagem);
    }
    return ErroServidorException(
      statusCode: statusCode,
      mensagem: mensagem ?? 'O servidor retornou um erro (status $statusCode).',
    );
  }

  Duration? _retryAfter(Response<dynamic>? resposta) {
    final String? valor = resposta?.headers.value('retry-after');
    final int? segundos = int.tryParse(valor?.trim() ?? '');
    return segundos == null ? null : Duration(seconds: segundos);
  }

  String? _mensagemDoCorpo(Object? dados) {
    final Object? mensagem = dados is Map ? dados['mensagem'] : null;
    return mensagem is String && mensagem.isNotEmpty ? mensagem : null;
  }

  AppException _mapearErroStream(Object erro) {
    if (erro is ErroHttpSse) {
      return _mapearStatus(erro.statusCode);
    }
    if (erro is HeartbeatSseExpiradoException) {
      return const RequisicaoExpiradaException();
    }
    if (erro is AppException) return erro;
    return const SemConexaoException();
  }
}
