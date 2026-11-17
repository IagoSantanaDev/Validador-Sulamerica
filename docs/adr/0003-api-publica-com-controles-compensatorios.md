# API pública com controles compensatórios

Nesta entrega, a API continua sem autenticação individual para evitar introduzir
um fluxo de identidade para os 12 usuários. Essa escolha deixa chamadas diretas
possíveis para qualquer pessoa que conheça um identificador; CORS não autentica
clientes e rate limit não protege a confidencialidade dos dados. Aceitamos esse
risco nesta entrega e o reduzimos com allowlist CORS no Render, rate limits,
limite total de execuções e de streams, logs redigidos, contadores agregados e
alertas operacionais configurados fora do código. Não registrar identificadores,
origens específicas ou credenciais neste documento.
