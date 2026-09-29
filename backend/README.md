# API intermediária do Validador SulAmerica

Backend do Validador SulAmerica: proxy em Dart (shelf) entre o app Flutter Web e o portal da SulAmérica (Lumis DOUI). O app nunca chama o portal direto; toda login, consulta de elegibilidade e consulta de autorização passa por aqui.

O código vive em `backend/`, separado do app. A sessão do portal é mantida no servidor (CookieJar em memória), nunca no navegador.

## Por que o proxy existe

Dois bloqueios impedem chamada direta do navegador ao portal:

1. O portal não envia `Access-Control-Allow-Origin`, então o navegador não lê as respostas (CORS).
2. Os cookies de sessão (JSESSIONID, lum*, NSC_* do F5) são `SameSite=Strict` e `HttpOnly`, então não trafegam entre origens.

A API resolve os dois: mantém a sessão do portal no servidor e expõe JSON para o app.

## Como rodar

Pré-requisito: Dart 3.3+.

```bash
cd backend
dart pub get
dart run bin/server.dart
```

O servidor escuta em `0.0.0.0:8080`.

Variáveis de ambiente opcionais:

| Variável | Padrão | Descrição |
|---|---|---|
| `PORT` | `8080` | Porta HTTP |
| `HOST` | `0.0.0.0` | Interface de escuta |
| `CORS_ORIGIN` | `*` | Origem permitida (ex.: `https://validador-tiss.pages.dev`) |
| `PORTAL_PRESTADOR_ID_<IDENTIFICADOR>_CODE` | — | `code` do prestador no portal |
| `PORTAL_PRESTADOR_ID_<IDENTIFICADOR>_USER` | — | `user` do prestador no portal |
| `PORTAL_PRESTADOR_ID_<IDENTIFICADOR>_SENHA` | — | `senha` do prestador no portal |
| `PORTAL_CERT_FINGERPRINT_SHA256` | — | Fingerprint SHA256 (hex) do certificado do portal; sem ele vale a validação de CA padrão |

`CORS_ORIGIN` é lida em runtime, então dá para ajustar sem recompilar. As credenciais e o fingerprint do certificado também são lidos em runtime.

### Credenciais do prestador

O backend resolve `code`, `user` e `senha` no servidor, a partir de variáveis de ambiente. O app nunca os envia: `POST /api/login` recebe só `{identificadorPrestador}`, e o identificador em MAIÚSCULAS define o prefixo das variáveis (`PORTAL_PRESTADOR_ID_<IDENTIFICADOR>_CODE|_USER|_SENHA`, ver `lib/modules/sulamerica/data/credenciais_portal.dart`).

Comportamento: `identificadorPrestador` ausente ou vazio → 400; identificador sem trio completo de variáveis não vazias → 401. Nenhum log imprime credenciais nem o identificador em claro.

## Como o backend fala com o portal

Os detalhes abaixo foram validados contra o portal em produção e precisam continuar assim.

- O login começa com um GET na página para semear JSESSIONID e NSC_*; um POST direto devolve 403 do F5 ASM. O GET usa headers de navegador (User-Agent, Accept, Accept-Language, Upgrade-Insecure-Requests); sem eles o portal devolve 500.
- Login aceito responde 302 para `/prestador/`. O backend segue o redirect via GET com a sessão e confirma a página autenticada (procura por "logout" no corpo) antes de marcar a sessão como válida.
- A consulta de beneficiário também redireciona (302 para `elegibilidade-resultado.htm`); o backend segue o redirect e devolve o HTML final.
- A consulta de autorização é um GET em `ajax-controller.jsp` com `metodo=autorizador-pesquisar-solicitacoes` e o campo `numero-vpp` (a senha de 10 dígitos do beneficiário). O portal devolve `text/plain` em ISO-8859-1; o backend tenta UTF-8 e cai para Latin-1. Esse endpoint exige sessão autenticada (401 sem login).
- A carteirinha é enviada nos segmentos originais 3-5-4-4-4 (campos `codigo-beneficiario-1` a `codigo-beneficiario-5`), não dividida em partes iguais.
- O certificado TLS do portal tem cadeia com self-signed que a CA pública dos containers rejeita. O backend **nunca** aceita o certificado apenas porque o hostname bate: `SessaoPortal` sempre valida. A estratégia é: validação de CA padrão por padrão; se `PORTAL_CERT_FINGERPRINT_SHA256` estiver configurado, a conexão passa por pinning do fingerprint SHA256 do certificado (dependência `crypto`), e a comparação é feita sobre o DER apresentado.
- Rotação do certificado: o pinning é atualizado trocando o valor de `PORTAL_CERT_FINGERPRINT_SHA256`, sem recompilar e sem deploy de código. Sem a variável configurada, um certificado self-signed faz a conexão com o portal falhar, e o login responde 401 por falha de rede.

## Endpoints

| Método | Rota | Corpo / Query | Descrição |
|---|---|---|---|
| POST | `/api/login` | `{identificadorPrestador}` | Autentica no portal e devolve `{token, autenticada: true}` |
| POST | `/api/consultas` | `{token, consultas: [{tipo, chave}]}` | Consultas em lote; devolve `{status, resultados}` na ordem da requisição |
| GET | `/api/status` | nenhum | Health check: sessões ativas e teste de alcance do portal |

Qualquer outra rota devolve 404.

O teste de alcance de `/api/status` usa um `HttpClient` comum, sem o adapter de `SessaoPortal` e sem pinning. Ele responde pela rede, não pela sessão do portal: um certificado self-signed pode aparecer como `alcançavel: false`.

Regras de negócio aplicadas no servidor, espelhando o app:

- Carteira precisa ter exatamente 20 dígitos.
- Senha precisa ter exatamente 10 dígitos e começar com 5.
- Elegibilidade é lida da página de resultado (`elegivel` `true` ou `false`); `null` quando o portal volta para a página de identificação, o que acontece quando a carteira não é encontrada.
- O item de resultado de tipo `senha` devolve `statusSenha` com a descrição do status (ex.: "Autorizado", "Negado") ou `null` quando não há registro. O backend não repassa o JSON cru do portal.
- O app considera a senha autorizada quando a descrição contém "autorizado".

### Exemplos

```bash
curl http://localhost:8080/api/status

curl -X POST http://localhost:8080/api/login \
  -H 'Content-Type: application/json' \
  -d '{"identificadorPrestador":"<identificador>"}'
```

## Consultas em lote

`/api/consultas` recebe as solicitações de um arquivo e devolve `{status: "ok", resultados: [...]}` com os resultados na ordem da requisição. Cada item é `{tipo: "elegibilidade"|"senha", chave: <carteira ou senha>}`.

A ordem de validação é: primeiro o payload, depois o token.

- `consultas` ausente, não é lista ou vazia → 400.
- Mais de 300 itens → 413.
- Item que não é objeto, ou com `tipo`/`chave` ausentes, não string ou vazios → 400, citando o índice do item. É uma resposta de validação, não um 500.
- Token ausente ou inválido → 401.

O frontend respeita esse teto: `validador_controller.dart` limita cada chamada a 300 itens (`_maxConsultasPorLote`) e particiona arquivos maiores, recompondo os resultados por `tipo|chave`.

Execução contra o portal:

- Elegibilidade roda em série por sessão, porque o form do portal tem estado.
- Consultas de senha rodam em paralelo, até 3 por sessão.
- Lotes com 10 ou mais elegibilidades abrem sessões extras (logins paralelos) até o teto de 10 sessões; as extras são encerradas ao final do lote.
- Recuperação de falha: sessão rejeitada (401/403) renova o login e repete a consulta uma vez; falha transitória de rede aguarda 500 ms e repete.
- Falhas de formato (carteira ou senha inválida) viram erro no próprio item, sem tocar o portal.

## Limites e proteções

| Limite | Valor | Resposta |
|---|---|---|
| Itens por lote | 300 | 413 |
| Tamanho do corpo | 1 MB | 413 |
| Rate limit nas rotas do portal (`/api/login`, `/api/consultas`) | 40 por minuto | 429 |
| Lotes simultâneos | 1 | 429 |
| Sessões ativas | 10 (a mais antiga é encerrada) | nova sessão substitui a antiga |

O estado das sessões é local ao processo: não há réplica nem estado compartilhado, o que é outra razão para o serviço rodar com instância única.

Tokens de sessão são gerados com `Random.secure()`. Sem credenciais válidas, o backend nega o login com 401 e mensagem com o motivo (credencial, rede ou resposta inesperada do portal).

## Segurança

- As credenciais do prestador nunca chegam pelo app: o `/api/login` recebe só o identificador e `CredenciaisPortal` resolve `code`/`user`/`senha` das variáveis de ambiente. Elas não estão no bundle do front nem em nenhum artefato de build.
- A senha do prestador nunca é logada e não persiste; as credenciais ficam retidas em memória por token, apenas para abrir sessões extras, e saem junto com a sessão.
- Logs registram método, rota e status, nunca corpo nem credenciais. Chaves (carteira/senha) aparecem mascaradas, ex.: `5820...10`. O identificador do prestador também não é logado em claro.
- O rate limit identifica o cliente pelo endereço de conexão real (`shelf.io.connection_info`) e não considera header de proxy enviado pelo cliente, que poderia forjar o identificador e escapar do limite. A consequência é que, atrás de um proxy, todos os clientes compartilham o mesmo endereço e a contagem fica agregada por proxy.
- Em produção: rodar atrás de TLS e restringir `CORS_ORIGIN` e a rede de acesso à API.

## Deploy (Render free tier)

O repo tem um blueprint (`render.yaml` na raiz) que cria o serviço `validador-api` a partir do `backend/Dockerfile` (multi-stage: compila binário nativo e roda em uma imagem mínima Debian).

Pontos que precisam continuar como estão:

- Instância única. A sessão do portal vive em memória; réplicas quebrariam a autenticação.
- No free tier o Render dorme após cerca de 15 minutos ocioso. O cold start leva alguns segundos e a sessão do portal se perde; o front re-autentica na próxima consulta.
- `CORS_ORIGIN` precisa apontar para o domínio do front em produção.
- Push no git dispara redeploy automático.

Para o front, o build aponta para a URL do serviço:

```bash
flutter build web --release --dart-define=API_URL=https://validador-api.onrender.com
```

## Testes

```bash
dart test
dart analyze
```

Os testes cobrem o parser de elegibilidade, a classificação de falhas de sessão (401/403 vs. transitórias) e o resumo de texto dos logs.