export 'sse_client_stub.dart'
    show
        ConexaoSse,
        ErroHttpSse,
        EventoSse,
        HeartbeatSseExpiradoException,
        SseParser;

export 'sse_client_stub.dart'
    if (dart.library.js_interop) 'sse_client_web.dart'
    show abrirEventosSse;
