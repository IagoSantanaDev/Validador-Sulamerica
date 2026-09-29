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

1. O site abre e verifica a API (`/api/status`) e autentica no portal com as credenciais definidas no build. Enquanto isso não acontece, a página mostra o motivo exato: API fora do ar, credenciais ausentes ou credenciais inválidas.
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

O conjunto VPP em runtime é um snapshot de 2.792 códigos com `VPP = Sim`, gerado em `lib/modules/validador_xml/data/repositories/regras/codigos_vpp.dart`. A fonte de referência `debug/KAN-07/procedimentos_vpp_sim.json` identifica `LISTA DE SERVIÇOES QUE EXIGEM AUTORIZAÇÃO.pdf` e o critério `VPP = Sim`, mas não informa edição ou data de vigência. Ao atualizar a fonte, atualize o conjunto Dart junto; o teste `regra_senha_procedimento_test.dart` verifica contagem, unicidade e igualdade integral. O app não lê o JSON em runtime. Para executar esse teste quando a fonte não estiver no caminho padrão, defina `KAN_07_VPP_JSON` com o caminho do arquivo.

### Consultas ao portal

Depois da validação local, cada guia com dados válidos é consultada. Carteira e senha só geram chamada quando passam na verificação de formato; senão viram erro local sem tocar o portal.

- **Elegibilidade (carteira)**: devolve SIM ou NÃO. NÃO vira "Beneficiário não elegível"; quando o portal não renderiza o resultado, "Carteira não encontrada no portal".
- **Autorização (senha)**: devolve a descrição do status da solicitação. Descrição com "autorizado" é sucesso; sem status, "Senha não encontrada no portal"; nos demais casos a descrição do portal é exibida.

As consultas vão todas para `/api/consultas` em uma única chamada HTTP. O backend distribui o trabalho em até 10 sessões do portal (carteiras em série por sessão, senhas com até 3 simultâneas por sessão), preserva a ordem do lote e recupera falhas: sessão rejeitada (401/403) renova o login, falha transitória repete após pausa curta. O app guarda um fallback para chamadas individuais, usado apenas se o backend for um deploy antigo sem `/api/consultas`.

## Como rodar localmente

Pré-requisitos: Flutter 3.19+ e Dart 3.3+.

### Backend

```bash
cd backend
dart pub get
dart run bin/server.dart
```

O servidor escuta em `0.0.0.0:8080`. Variáveis de ambiente opcionais: `PORT` (padrão 8080), `HOST` (padrão 0.0.0.0) e `CORS_ORIGIN` (padrão `*`).

### Frontend

```bash
flutter pub get
flutter run -d chrome --dart-define=API_URL=http://localhost:8080
```

Com `API_URL` apontando para o backend local, o site já libera a tela de upload — o login em si só acontece depois que um arquivo é carregado, com a credencial do prestador daquele lote (ver `RegraCredenciaisPortal`).

## Variáveis de build do frontend

Definidas em tempo de build com `--dart-define`. Não há mais um prestador "padrão": um lote de um CNPJ/codigoPrestadorNaOperadora sem credencial cadastrada abaixo simplesmente não consegue autenticar (erro fica só naquele lote, a tela de conexão não é afetada).

| Variável | Descrição |
|---|---|
| `API_URL` | URL da API intermediária. Padrão `http://localhost:8080` |
| `PORTAL_CODE_CEMED` / `PORTAL_USER_CEMED` / `PORTAL_SENHA_CEMED` | Credenciais do prestador CNPJ/codigoPrestadorNaOperadora `27372066000673` (ver `RegraCredenciaisPortal`) |
| `PORTAL_CODE_HSR` / `PORTAL_USER_HSR` / `PORTAL_SENHA_HSR` | Credenciais do prestador CNPJ/codigoPrestadorNaOperadora `27372066000169` |

## Deploy

### Backend (Render)

O repo tem um blueprint (`render.yaml`) que cria o serviço `validador-api` a partir do `backend/Dockerfile`, no free tier. O serviço precisa rodar com instância única: a sessão do portal vive em memória, então réplicas quebrariam a autenticação. No free tier o Render dorme após cerca de 15 minutos ocioso e a sessão se perde; o front re-autentica na próxima visita.

Para criar: no dashboard do Render, New +, Blueprint, e selecione o repositório. A URL fica em `https://validador-api.onrender.com` (ajuste o `CORS_ORIGIN` para o domínio do front em produção).

### Frontend (Cloudflare Pages)

```bash
flutter build web --release \
  --dart-define=API_URL=https://validador-api.onrender.com \
  --dart-define=PORTAL_CODE_CEMED=... --dart-define=PORTAL_USER_CEMED=... --dart-define=PORTAL_SENHA_CEMED=... \
  --dart-define=PORTAL_CODE_HSR=... --dart-define=PORTAL_USER_HSR=... --dart-define=PORTAL_SENHA_HSR=...

npx wrangler pages deploy build/web --project-name validador-tiss
```

## Endpoints da API

| Método | Rota | Corpo / Query | Descrição |
|---|---|---|---|
| POST | `/api/login` | `{code, user, senha}` | Autentica no portal e devolve `{token}` |
| POST | `/api/beneficiario` | `{token, carteira}` | Elegibilidade de uma carteira |
| GET | `/api/autorizacao` | `?token=&senha=` | Status da autorização pela senha |
| POST | `/api/consultas` | `{token, consultas: [{tipo, chave}]}` | Consultas em lote, resultados na ordem da requisição |
| GET | `/api/status` | nenhum | Health check, sessões ativas e alcance do portal |

Limites do backend, para não abusar do proxy: 300 itens por lote, corpo de até 1 MB, rate limit de 40 requisições por minuto por IP nas rotas que tocam o portal e no máximo 10 sessões ativas (a mais antiga sai quando o limite é atingido).

## Testes

```bash
flutter test        # app (raiz)
flutter analyze

dart test           # backend
dart analyze        # dentro de backend/
```

## Segurança

- A senha do prestador nunca é logada; é usada só no login e as credenciais ficam retidas em memória, por token, para abrir sessões extras. Saem junto com a sessão.
- Tokens de sessão são gerados com `Random.secure()` e mantidos em memória.
- Os logs registram método, rota e status, nunca corpo nem credenciais.
- O backend usa `Random.secure()`, valida formatos de carteira e senha no servidor e mascara chaves em logs (ex.: `5820...10`).

Uma observação honesta: as credenciais do portal vão embutidas no bundle do front (são `--dart-define`). Quem baixar o site consegue lê-las. Isso é um risco assumido; em produção, vale restrigir `CORS_ORIGIN` e limitar a rede de acesso à API, além de usar um usuário de prestador com privilégios mínimos.

## Limitações conhecidas

- A sessão do portal vive em memória no backend: sem réplicas, e o cold start do free tier do Render perde a sessão (o front re-autentica).
- O app exige API acessível e login válido para validar; não há modo local sem conexão.
- O parsing cobre guias `guiaSP-SADT`; outros tipos de guia TISS não são lidos.