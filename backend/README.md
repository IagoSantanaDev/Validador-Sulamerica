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
| `CORS_ORIGIN` | `*` | Origem(ens) permitida(s), separadas por vírgula (ex.: `https://validador-sulamerica.pages.dev, http://localhost:3000`) |
| `PORTAL_PRESTADOR_ID_<IDENTIFICADOR>_CODE` | — | `code` do prestador no portal |
| `PORTAL_PRESTADOR_ID_<IDENTIFICADOR>_USER` | — | `user` do prestador no portal |
| `PORTAL_PRESTADOR_ID_<IDENTIFICADOR>_SENHA` | — | `senha` do prestador no portal |

`CORS_ORIGIN` é lida em runtime, então dá para ajustar sem recompilar. As credenciais também são lidas em runtime.

### Formato do CORS_ORIGIN

`CORS_ORIGIN` aceita **uma ou mais** origens, separadas por vírgula:

```
CORS_ORIGIN=https://validador-sulamerica.pages.dev, http://localhost:3000
```

Regras:

- Espaços em volta de cada item são ignorados, e itens vazios (vírgula dupla ou vírgula no fim) são descartados.
- A barra final é **opcional**: um *origin* da spec é esquema + host + porta, sem path e sem barra. Tanto `https://x.pages.dev` quanto `https://x.pages.dev/` casam com o header `Origin` que o navegador envia.
- A resposta ecoa em `Access-Control-Allow-Origin` **exatamente uma** origem: a que casa com o `Origin` da requisição. Esse header não aceita lista; ecoar as duas faz o navegador recusar a chamada com `The 'Access-Control-Allow-Origin' header contains multiple values`.
- Origem fora da lista **não** recebe o header, e o navegador bloqueia. Não há fallback para `*` quando há lista explícita.
- `CORS_ORIGIN` ausente (ou vazia) vale `*`, o default de desenvolvimento. `*` dentro da lista também significa "qualquer origem".
- Quando a resposta depende da origem, o backend envia `Vary: Origin`, para que um cache compartilhado (CDN/proxy) não sirva a resposta montada para uma origem a outra. Com `*` não há `Vary`, porque a resposta é a mesma para qualquer origem.

O mesmo vale para o preflight `OPTIONS`: ele segue a mesma comparação e devolve só a origem que casou.

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
- O TLS fica por conta da validação padrão do `dart:io`: cadeia do certificado contra as raízes confiáveis do sistema **e** o hostname do certificado. Não há pinning.
- Verificado em 2026-09-29: o portal (`saude.sulamericaseguros.com.br`) **emite certificado de CA pública**, emitido por `GeoTrust TLS RSA CA G1` (DigiCert), válido até 2026-10-25, com SAN `*.sulamericaseguros.com.br`. O handshake com a validação de CA padrão do Dart **passa**.
- Pinning por fingerprint foi removido de propósito. A OWASP não recomenda pinning fora de aplicativo nativo, e o risco de queda na rotação do certificado supera o ganho. Concretamente: o portal fica atrás do `radwarecloud.net`, que pode atender por nós de borda distintos, e o certificado de CA pública renova sozinho — um valor de fingerprint preenchido por engano derrubava **todas** as conexões com o portal, reportadas como "falha de rede". Se um dia o portal sair de CA pública, a falha será de `badCertificate`, visível no log, e o pinning volta a ser avaliado com pinset de backup.
- `SessaoPortal.validarCertificado` roda **depois** da cadeia já ter sido aceita pelo `HttpClient` (é o contrato do `dio`) e serve só para registrar em log um certificado de outro host, o que indicaria redirecionamento ou interceptação.

## Endpoints

| Método | Rota | Corpo / Query | Descrição |
|---|---|---|---|
| POST | `/api/login` | `{identificadorPrestador}` | Autentica no portal e devolve `{token, autenticada: true}` |
| POST | `/api/consultas` | `{token, consultas: [{tipo, chave}]}` | Consultas em lote; devolve `{status, resultados}` na ordem da requisição |
| GET | `/api/status` | nenhum | Health check: sessões ativas e teste de alcance do portal |

Qualquer outra rota devolve 404.

O teste de alcance de `/api/status` usa um `HttpClient` comum, sem o adapter de `SessaoPortal` e sem pinning. Ele responde pela rede, não pela sessão do portal: se o certificado deixar de ser válido por CA pública, aparece como `alcançavel: false`. O resultado é cacheado por alguns segundos para não gerar um handshake por requisição.

O resultado do teste de alcance é **cacheado por 10 segundos** e compartilhado por todas as requisições. Sem isso, cada `GET /api/status` de um cliente anônimo-forjador abriria um handshake TLS de saída, e o próprio health check do Render dispararia rede a cada sondagem. Uma janela de 10 s limita o serviço a no máximo 6 handshakes por minuto, independentemente da taxa de chamadas. Expirada a janela, a próxima chamada volta a testar o portal — o health check não fica mentirindo sobre o estado do portal.

`/api/status` fica **fora** do rate limit de propósito. O Render considera a instância saudável apenas com 2xx/3xx: um 429 conta como falha de saúde, o Render para de rotear tráfego após 15 s de falhas consecutivas e reinicia a instância se a condição persistir por 60 s. Como `render.yaml` usa `healthCheckPath: /api/status`, incluir a rota no rate limit transformaria um pico de tráfego em indisponibilidade do serviço. A proteção contra abuso é o cache da sonda, que já limita as saídas de rede a 1 por janela; a resposta anônima e barata não precisa de 429.

Quando a sonda falha, a resposta pública é apenas `{"alcançavel": false}` dentro de `portalSulAmerica`. O erro bruto (`subject`/`issuer` do certificado, endereço interno) fica **apenas no log do servidor**: a rota é anônima e não tem o que autenticar quem pergunta.

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
| Cache do teste de alcance de `/api/status` | 10 segundos | — (reaproveita a última sonda) |
| Lotes simultâneos | 1 | 429 |
| Sessões ativas | 10 (a mais antiga ociosa é encerrada) | nova sessão substitui a antiga |
| Sessões em uso por um lote | — | 503 no login, sem encerrar a sessão ativa |

O estado das sessões é local ao processo: não há réplica nem estado compartilhado, o que é outra razão para o serviço rodar com instância única.

Tokens de sessão são gerados com `Random.secure()`. Sem credenciais válidas, o backend nega o login com 401 e mensagem com o motivo: credencial recusada, falha de rede, erro interno do backend ou resposta inesperada do portal. "Falha de rede" significa **só** `DioException`; qualquer outro erro vira `Falha interna ao processar a resposta do portal SulAmerica.`, para não mandar o usuário investigar a rede quando o defeito está no backend. O tipo da exceção (`connectionError`, `badCertificate`, `timeout`…) fica no log do servidor.

### Ciclo de vida da sessão

Uma sessão só é descartada por evicção (atingiu o teto de 10) ou quando a sessão do lote extra é criada para uma chamada. A sessão **nunca é encerrada no meio de uma consulta**: `_novoToken` ignora o token cujo lote está em andamento e escolhe a mais antiga entre as ociosas. Como só existe um lote simultâneo, basta proteger esse token.

Se todas as 10 sessões estiverem em uso — o que, com um único lote por vez, é o caso degenerado em que o limite é 1 e a sessão está ocupada — o login responde **503** com a mensagem `Limite de sessoes ativas em uso. Tente novamente em instantes.` e encerra a sessão que ele mesmo acabou de criar, em vez de matar a sessão ativa. Fechar o `Dio` de um lote em voo quebraria as consultas restantes sem avisar o cliente.

`encerrar()` é aguardado (`await`) na evicção e no descarte da sessão do login recusado, para que o socket do portal feche antes do handler responder.

## Segurança

- As credenciais do prestador nunca chegam pelo app: o `/api/login` recebe só o identificador e `CredenciaisPortal` resolve `code`/`user`/`senha` das variáveis de ambiente. Elas não estão no bundle do front nem em nenhum artefato de build.
- A senha do prestador nunca é logada e não persiste; as credenciais ficam retidas em memória por token, apenas para abrir sessões extras, e saem junto com a sessão.
- Logs registram método, rota e status, nunca corpo nem credenciais. Chaves (carteira/senha) aparecem mascaradas, ex.: `5820...10`. O identificador do prestador também não é logado em claro.
- Detalhes internos não saem em respostas não autenticadas. A falha de rede do `/api/login` responde só com `Falha de rede ao acessar o portal SulAmerica.`; o detalhe do `Dio` (URL, fragmento de requisição, tipo da exceção) vai para o log. O mesmo vale para `/api/status`, que devolve apenas `alcançavel: false` quando a sonda falha. Ambos os detalhes ficam disponíveis no log do servidor para diagnóstico.
- O rate limit identifica o cliente pelo endereço de conexão real (`shelf.io.connection_info`) e não considera header de proxy enviado pelo cliente, que poderia forjar o identificador e escapar do limite. A consequência é que, atrás de um proxy, todos os clientes compartilham o mesmo endereço e a contagem fica agregada por proxy.
- Em produção: rodar atrás de TLS e restringir `CORS_ORIGIN` e a rede de acesso à API.

## Deploy (Render free tier)

O repo tem um blueprint (`render.yaml` na raiz) que cria o serviço `validador-api` a partir do `backend/Dockerfile` (multi-stage: compila binário nativo e roda em uma imagem mínima Debian).

Pontos que precisam continuar como estão:

- Instância única. A sessão do portal vive em memória; réplicas quebrariam a autenticação.
- No free tier o Render dorme após cerca de 15 minutos ocioso. O cold start leva alguns segundos e a sessão do portal se perde; o front re-autentica na próxima consulta.
- `CORS_ORIGIN` precisa apontar para o domínio do front em produção. Com mais de um ambiente (produção + localhost), use a lista separada por vírgula; veja "Formato do CORS_ORIGIN".
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