# API intermediária — Validador de Guias TISS SulAmérica

Proxy entre o app Flutter Web e o portal da SulAmérica (Lumis DOUI).
Resolve os dois bloqueios validados empiricamente:

1. **CORS** — o portal não envia `Access-Control-Allow-Origin`; o navegador
   não consegue ler as respostas (login/consulta/autorização).
2. **Sessão cross-site** — os cookies do portal são `SameSite=Strict` +
   `HttpOnly` (JSESSIONID, lum*, NSC do F5); o navegador num app externo não
   os envia nem os recebe.

A sessão do portal vive aqui (CookieJar em memória), nunca no navegador.

> Requisito operacional (validado): o login **precisa** começar com um `GET`
> na página de login para semear `JSESSIONID`/`NSC_*` — um `POST` direto
> retorna 403 do F5 ASM. O `SessaoPortal.login()` faz isso automaticamente.

## Como rodar

```bash
cd backend
dart pub get
dart run bin/server.dart          # escuta em 0.0.0.0:8080
```

Variáveis de ambiente (opcionais):

| Variável | Padrão | Descrição |
|---|---|---|
| `PORT` | `8080` | Porta HTTP |
| `HOST` | `0.0.0.0` | Interface de escuta |
| `CORS_ORIGIN` | `*` | Origem permitida (ex.: `https://validador-tiss.pages.dev`) — lida em runtime, serve via `railway variables set` |

## Deploy (Render free tier)

O backend é empacotado como container (`render.yaml` na raiz do repo +
`backend/Dockerfile`) com **instância única** — a sessão do portal SulAmérica
vive em memória, então não habilite réplicas/escala horizontal (quebrariam a
sessão). No free tier o serviço **dorme após ~15 min ocioso** e acorda na
próxima requisição (cold start de alguns segundos); ao dormir, a sessão do
portal é perdida e o front re-autentica.

### Deploy (primeira vez)

1. Suba o repo num repositório Git remoto (GitHub/GitLab).
2. No dashboard do Render: **New + → Blueprint** → selecione o repo.
   O `render.yaml` na raiz cria o serviço `validador-api`.
3. Pronto: URL `https://validador-api.onrender.com`.

Ajustes posteriores (dashboard → service → Settings):

- **CORS_ORIGIN**: trocar `*` pelo domínio do front (`https://validador-tiss.pages.dev`).
- **Mudanças no código**: push no git dispara redeploy automático.

Frontend:

```bash
flutter build web --release --dart-define=API_URL=https://validador-api.onrender.com
npx wrangler pages deploy build/web --project-name validador-tiss
```

Custo: free tier (750h/mês, 0.5 GB RAM, 1 shared vCPU, sem cartão). Como o
serviço dorme quando ocioso, fica bem abaixo das 750h — grátis.

## Endpoints

| Método | Rota | Corpo / Query | Descrição |
|---|---|---|---|
| `POST` | `/api/login` | `{code, user, senha}` | Autentica no portal e devolve `{token}` |
| `POST` | `/api/beneficiario` | `{token, carteira}` | Consulta o beneficiário; devolve `{status, elegivel, rotuloElegibilidade, html}` |
| `GET` | `/api/autorizacao` | `?token=&numeroVpp=` | Consulta a autorização VPP; devolve o JSON do portal |
| `GET` | `/api/status` | — | Health check (número de sessões ativas) |

Regras de negócio aplicadas no proxy (espelhando o app):

- a **carteirinha** é dividida nos segmentos fixos **3-5-4-4-4** dígitos
  (ex.: `58201824004384300010` → 582/01824/0043/8430/0010);
- **VPP** (`ajax-controller.jsp`) exige sessão autenticada — sem login o
  portal responde 401;
- a autorização só é válida quando algum registro tem
  `status_solicitacao.descricao == "Autorizado"`;
- **elegibilidade** é extraída do `elegibilidade-resultado.htm` (o POST da
  consulta redireciona para essa página): o valor está no bloco
  `div.box-indicador-elegibilidade`, em
  `<strong>Elegível:</strong> <span class="atencao">SIM|NÃO</span>`.
  `elegivel: true|false` quando há resultado; `null` quando o portal volta
  para a página de identificação (carteira não encontrada).

## Segurança

- Senha **nunca** é armazenada nem logada; é usada apenas na chamada do
  login e descartada.
- Tokens de sessão são gerados com `Random.secure()` (32 hex) e mantidos em
  memória (limite de 10 sessões ativas).
- Log só registra método/rota/status — nunca corpo nem credenciais.
- Para produção: rode atrás de TLS e restrinja `CORS_ORIGIN` e a rede de
  acesso à API.