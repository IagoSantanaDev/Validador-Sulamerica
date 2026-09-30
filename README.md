# Validador SulAmerica

Validador de arquivos XML no padrão TISS da ANS para pré-validar lotes de guias antes do envio à SulAmérica. O app lê o lote, aplica regras de negócio por guia e consulta o portal da operadora para conferir elegibilidade e autorização em tempo real.

O projeto tem duas partes:

- **Frontend**: app Flutter Web que recebe o XML por drag and drop e mostra o resultado da validação.
- **Backend**: API intermediária em Dart (shelf) que fala com o portal SulAmérica em nome do app.

## Por que uma API intermediária

O portal da SulAmérica não pode ser chamado diretamente do navegador. Dois bloqueios:

1. O portal não envia `Access-Control-Allow-Origin`, então o navegador não consegue ler as respostas (CORS).
2. Os cookies de sessão do portal (JSESSIONID, lum*, NSC do F5) são `SameSite=Strict` e `HttpOnly`, então não trafegam entre origens.

A API intermediária resolve os dois: ela mantém a sessão do portal em memória (CookieJar no servidor) e expõe rotas JSON para o app. Chamadas de portal nunca partem do navegador.

```
Navegador (Flutter Web)
   |
   | HTTPS para a nossa API
   v
API intermediária (Dart, shelf)
   |
   | GET inicial + POST, cookies do portal em memória
   v
Portal SulAmérica (saude.sulamericaseguros.com.br)
```

Um detalhe operacional validado: o login no portal precisa começar com um GET na página para semear os cookies JSESSIONID e NSC_*; um POST direto devolve 403 do F5 ASM. O `SessaoPortal.login()` faz isso automaticamente.

## Estrutura do repositório

```
.
├── backend/                  API intermediária (Dart + shelf)
│   ├── bin/server.dart       entrada, roteamento, limites (lote, rate limit)
│   ├── lib/                  rotas, sessão do portal, parser de elegibilidade
│   └── test/
├── lib/                      app Flutter Web
│   ├── globals/              network (dio), temas, widgets, constantes
│   └── modules/validador_xml/
│       ├── data/             parsing do XML, regras, serviços, modelos
│       └── presentation/     página, controller e widgets
├── test/                     testes do app
├── web/                      index.html do Flutter Web
├── render.yaml               blueprint do Render (backend)
└── pubspec.yaml
```

## Como funciona a validação

1. O site abre e verifica a API (`/api/status`). O login no portal acontece depois que um arquivo é carregado: o app envia o identificador do prestador daquele lote e o backend resolve as credenciais no servidor, a partir de secrets. Enquanto isso não acontece, a página mostra o motivo exato: API fora do ar, credenciais ausentes ou credenciais inválidas.
2. Você arrasta um arquivo `.xml` de lote TISS para a área de upload. O app calcula o hash MD5 e extrai os metadados do lote.
3. A validação local roda as regras por guia.
4. As guias com dados bem formados são consultadas no portal, em lote: elegibilidade pela carteira e status da autorização pela senha.
5. O resultado lista as guias com problema, cada uma com suas validações, filtros por tipo de erro e o tempo de processamento.

Metadados exibidos no resultado: nome e tamanho do arquivo, versão do padrão TISS (lida de `ans:Padrao`), tipo de transação, hash MD5, prestador, registro ANS, número do lote, quantidade de guias e valor total informado (soma dos `valorTotalGeral` do XML).

### Regras de validação local

| Regra | Critério | Falha exibida |
|---|---|---|
| CRM do solicitante | conta literalmente os caracteres de `dadosSolicitante/profissionalSolicitante/numeroConselhoProfissional`; mais de 5 falha. Valor ausente ou vazio é ignorado; não há `trim` nem remoção de zeros. | "CRM deve ter no máximo 5 dígitos (<número extraído>)" |
| Senha obrigatória | guia sem `<senha>` falha; quando há procedimento VPP, aplica-se a regra específica abaixo em vez desta mensagem genérica. | "Senha não informada" |
| Senha para procedimento VPP | um ou mais códigos com `VPP = Sim` exigem senha; é gerado um erro local único com todos os códigos aplicáveis. | "Senha obrigatória para procedimentos VPP: ..." |
| Prefixo da senha | a senha começa com 5 | "senha deve começar com 5" |
| Comprimento da senha | exatamente 10 caracteres | "senha deve ter exatamente 10 caracteres" |
| Carteira (antes da consulta) | 20 dígitos, segmentos 3-5-4-4-4 | "Número da carteira inválido" |
| Senha (antes da consulta) | 10 dígitos começando com 5 | "Senha inválida" |

O conjunto VPP em runtime é um snapshot de 2.792 códigos com `VPP = Sim`, gerado em `lib/modules/validador_xml/data/repositories/regras/codigos_vpp.dart`. A fonte de referência `debug/KAN-07/procedimentos_vpp_sim.json` identifica `LISTA DE SERVIÇOES QUE EXIGEM AUTORIZAÇÃO.pdf` e o critério `VPP = Sim`, mas não informa edição ou data de vigência. Ao atualizar a fonte, atualize o conjunto Dart junto; o teste `regra_senha_procedimento_test.dart` verifica contagem, unicidade e igualdade integral. O app não lê o JSON em runtime, e o teste também não: ele valida o conjunto gerado contra a contagem esperada em código.

### Consultas ao portal

Depois da validação local, cada guia com dados válidos é consultada. Carteira e senha só geram chamada quando passam na verificação de formato; senão viram erro local sem tocar o portal.

- **Elegibilidade (carteira)**: devolve SIM ou NÃO. NÃO vira "Beneficiário não elegível"; quando o portal não renderiza o resultado, "Carteira não encontrada no portal".
- **Autorização (senha)**: devolve a descrição do status da solicitação. Descrição com "autorizado" é sucesso; sem status, "Senha não encontrada no portal"; nos demais casos a descrição do portal é exibida.

As consultas vão para `/api/consultas`, sempre em lote. O frontend limita cada chamada a 300 itens (`_maxConsultasPorLote` em `validador_controller.dart`) e particiona arquivos maiores em várias chamadas, recompondo os resultados por `tipo|chave`; ordem, duplicatas e a associação de cada resultado à guia de origem são preservadas, e um lote parcial ou falho é tratado explicitamente, sem ser lido como sucesso. O backend distribui o trabalho em até 10 sessões do portal (carteiras em série por sessão, senhas com até 3 simultâneas por sessão), preserva a ordem do lote e recupera falhas: sessão rejeitada (401/403) renova o login, falha transitória repete após pausa curta. Não há rota individual de elegibilidade ou autorização: ambas viajam só pelo lote.

## Como rodar localmente

Pré-requisitos: Flutter 3.19+ e Dart 3.3+.

### Backend

```bash
cd backend
dart pub get
dart run bin/server.dart
```

O servidor escuta em `0.0.0.0:8080`. Variáveis de ambiente opcionais: `PORT` (padrão 8080), `HOST` (padrão 0.0.0.0) e `CORS_ORIGIN` (padrão `*`).

`CORS_ORIGIN` aceita **uma ou mais** origens separadas por vírgula. A resposta
devolve `Access-Control-Allow-Origin` com apenas a origem que casa com a
requisição; uma origem fora da lista não recebe o header. A barra final é
ignorada, mas o correto é omitir — um *origin* é esquema, host e porta, sem
caminho:

```
CORS_ORIGIN=https://validador-sulamerica.pages.dev, http://localhost:3000
```

### Frontend

```bash
flutter pub get
flutter run -d chrome --dart-define=API_URL=http://localhost:8080
```

Com `API_URL` apontando para o backend local, o site já libera a tela de upload — o login em si só acontece depois que um arquivo é carregado, e o app envia o identificador do prestador daquele lote (ver `RegraCredenciaisPortal`). Para o login resolver, o backend precisa ter as credenciais daquele prestador configuradas por secret; sem isso a API responde 401.

## Variáveis de build do frontend

A única variável de build do frontend é `API_URL`, definida em tempo de build com `--dart-define`.

| Variável | Descrição |
|---|---|
| `API_URL` | URL da API intermediária. Padrão `http://localhost:8080` |

Nenhuma credencial do portal é passada por `--dart-define`. `AppConfig` só lê `API_URL`, e o app envia para `POST /api/login` apenas `{identificadorPrestador}` — o `code`, o `user` e a `senha` nunca saem do servidor.

Os identificadores que o app aceita estão em `RegraCredenciaisPortal`: ela normaliza o valor (só dígitos) e reconhece os CNPJs/codigoPrestadorNaOperadora `27372066000673` e `27372066000169`. Um lote cujo prestador não esteja nessa lista não chega a chamar a API. Os dois são identificadores públicos do prestador, não segredo, e estão no código-fonte.

### Credenciais do portal (configuração do backend)

As credenciais reais ficam somente no backend, lidas de variáveis de ambiente/secrets em runtime por `CredenciaisPortal`. Para cada prestador, o identificador em MAIÚSCULAS define o prefixo:

| Variável | Descrição |
|---|---|
| `PORTAL_PRESTADOR_ID_<IDENTIFICADOR>_CODE` | `code` do prestador no portal |
| `PORTAL_PRESTADOR_ID_<IDENTIFICADOR>_USER` | `user` do prestador no portal |
| `PORTAL_PRESTADOR_ID_<IDENTIFICADOR>_SENHA` | `senha` do prestador no portal |

Exemplo de prefixo para o identificador `27372066000673`: `PORTAL_PRESTADOR_ID_27372066000673_CODE`, `..._USER` e `..._SENHA`.

Comportamento do `POST /api/login`:

- `identificadorPrestador` ausente ou vazio → 400.
- Identificador sem trio de variáveis correspondente → 401.
- As três variáveis precisam existir e ser não vazias; qualquer uma faltando conta como não configurado.
- Sucesso → `{token, autenticada: true}`.

Os identificadores que o app envia são informação pública; as credenciais não são. Nenhum log do backend imprime credenciais nem o identificador em claro.

## Deploy

### Backend (Render)

O repo tem um blueprint (`render.yaml`) que cria o serviço `validador-api` a partir do `backend/Dockerfile`, no free tier. O serviço precisa rodar com instância única: a sessão do portal vive em memória, então réplicas quebrariam a autenticação. No free tier o Render dorme após cerca de 15 minutos ocioso e a sessão se perde; o front re-autentica na próxima visita.

Para criar: no dashboard do Render, New +, Blueprint, e selecione o repositório. A URL fica em `https://validador-api.onrender.com`. No painel do serviço, em **Environment**, defina `CORS_ORIGIN` com o domínio do front em produção (e o `http://localhost:PORT` durante o desenvolvimento), no formato de lista descrito acima. Também defina as credenciais do portal (`PORTAL_PRESTADOR_ID_<ID>_CODE|_USER|_SENHA`): sem elas o login responde 401 para qualquer identificador. `PORTAL_CERT_FINGERPRINT_SHA256` deve ficar **vazia** — o portal emite certificado de CA pública, então a validação padrão já é a correta.

### Frontend (Cloudflare Pages)

O deploy é feito pelo Cloudflare Pages a partir do Git, não por `wrangler` local.
Configure em **Pages → seu projeto → Settings → Builds & deployments**:

| Campo | Valor |
|---|---|
| Build command | `flutter build web --release` |
| Build output directory | `build/web` |
| Root directory | `/` (a raiz do repositório) |

E em **Settings → Environment variables**, em **Production**:

| Nome | Valor |
|---|---|
| `API_URL` | `https://validador-api.onrender.com` |

`API_URL` é a única variável de que o bundle precisa — nenhuma credencial. O
Cloudflare injeta a variável no build, então o `index.html` servido já aponta
para a API de produção sem `--dart-define` manual.

Para validar localmente antes de commitar, o mesmo build roda na sua máquina:

```bash
flutter build web --release --dart-define=API_URL=https://validador-api.onrender.com
flutter run -d chrome
```

Isso é opcional e serve só para conferir. Não é o caminho de deploy. Um
diretório `build/web/` local pode ficar desatualizado e não deve ser publicado
manualmente: o Pages sempre constrói a partir do commit atual.

Não commitar credenciais reais, não colocá-las em YAML versionado e não publicá-las
em logs. A configuração do backend (`render.yaml`) também não deve carregar
segredos: use as variáveis de ambiente/secrets do serviço.

## Endpoints da API

| Método | Rota | Corpo / Query | Descrição |
|---|---|---|---|
| POST | `/api/login` | `{identificadorPrestador}` | Autentica no portal e devolve `{token, autenticada: true}` |
| POST | `/api/consultas` | `{token, consultas: [{tipo, chave}]}` | Consultas em lote, resultados na ordem da requisição |
| GET | `/api/status` | nenhum | Health check, sessões ativas e alcance do portal |

Limites do backend, para não abusar do proxy: 300 itens por lote, corpo de até 1 MB, rate limit de 40 requisições por minuto nas rotas que tocam o portal (contado pelo endereço de conexão real) e no máximo 10 sessões ativas (a mais antiga é encerrada quando o limite é atingido). O estado das sessões é local ao processo, sem réplica.

## Testes

```bash
flutter test        # app (raiz)
flutter analyze

dart test           # backend
dart analyze        # dentro de backend/
```

## Segurança

- As credenciais do prestador existem apenas no backend, lidas de secrets em runtime. O bundle web não carrega `code`, `user` nem `senha`: o app envia só o identificador do prestador.
- A senha do prestador nunca é logada; é usada só no login e as credenciais ficam retidas em memória, por token, para abrir sessões extras. Saem junto com a sessão.
- Tokens de sessão são gerados com `Random.secure()` e mantidos em memória.
- Os logs registram método, rota e status, nunca corpo nem credenciais. O identificador do prestador também não é logado em claro.
- O backend usa `Random.secure()`, valida formatos de carteira e senha no servidor e mascara chaves em logs (ex.: `5820...10`).

Como o bundle web não carrega segredo, o que ainda precisa de disciplina no servidor:

- restringir `CORS_ORIGIN` ao domínio do front em produção, em vez de `*` (aceita lista separada por vírgula);
- limitar a rede de acesso à API;
- usar, no portal, um usuário de prestador com privilégios mínimos;
- manter as credenciais só em secrets do serviço, fora de YAML versionado e de logs.

## Limitações conhecidas

- A sessão do portal vive em memória no backend: sem réplicas, e o cold start do free tier do Render perde a sessão (o front re-autentica).
- O app exige API acessível e login válido para validar; não há modo local sem conexão.
- O parsing cobre guias `guiaSP-SADT`; outros tipos de guia TISS não são lidos.