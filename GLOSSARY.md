# Validador SulAmérica

Contexto do proxy entre o app Flutter Web e o portal SulAmérica. O app nunca
fala com o portal; o backend mantém as sessões do portal e expõe a API do
validador.

## Linguagem

**Usuário do aplicativo**:
Pessoa que utiliza o Validador para analisar arquivos XML; não é o prestador nem
o identificador enviado ao backend.
_Avoid_: Prestador, identificador de prestador

**Prestador**:
Organização atendida pelo portal, identificada por um CNPJ.
_Avoid_: Cliente, empresa, conta

**Identificador de prestador**:
Valor público enviado pelo app para o backend resolver as credenciais do
prestador. Não é a credencial do portal.
_Avoid_: Login, usuário, CNPJ

**Credenciais do portal**:
Conjunto de valores usados para autenticar um prestador no portal SulAmérica.
Cada identificador de prestador resolve um único conjunto.
_Avoid_: Login

**Sessão do portal**:
Conexão autenticada com o portal SulAmérica, com seus cookies, mantida no
servidor.
_Avoid_: Login, cookie, conexão

**Sessão lógica**:
Autorização emitida pelo backend ao app, representada por um token opaco. Não
contém cookies do portal.
_Avoid_: Token de login, sessão do portal

**Lote**:
Conjunto de consultas enviado de uma vez pelo app para processamento.
_Avoid_: Batch, job, requisição

**Execução**:
Estado no servidor do processamento de um lote, da fila ao resultado final.
_Avoid_: Job, tarefa, processo

**Agendador de lotes**:
Componente em memória que limita a capacidade e alterna trabalho entre
identificadores e lotes.
_Avoid_: Fila global sem justiça

**Pool de sessões do portal**:
Conjunto limitado de sessões autenticadas compartilhadas por um identificador
de prestador.
_Avoid_: Sessão lógica, sessão do usuário

**Token de sessão lógica**:
Token opaco enviado no header `Authorization: Bearer` para associar operações
ao identificador e às execuções do cliente.
_Avoid_: Credencial do portal

**Chave de idempotência**:
Valor fornecido pelo cliente para reconhecer reenvios do mesmo lote sem criar
execuções duplicadas enquanto a execução original estiver disponível.
_Avoid_: Identificador de sessão

**Evento SSE**:
Atualização do progresso ou resultado de uma execução enviada por um stream
HTTP enquanto o lote está ativo.
_Avoid_: Retomada persistente

**Consulta**:
Item de um lote que pede elegibilidade de uma carteira ou o status de uma senha.
_Avoid_: Requisição, pesquisa, verificação

**Elegibilidade**:
Resposta do portal sobre uma carteira: elegível, não elegível ou não encontrada.
_Avoid_: Cobertura, autorização

**Senha**:
Número de autorização de 10 dígitos consultado no portal.
_Avoid_: Guia, protocolo, número
