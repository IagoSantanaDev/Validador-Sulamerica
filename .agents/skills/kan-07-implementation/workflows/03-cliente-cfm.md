# WF03: Cliente SOAP Do CFM

## Objetivo

Criar o adaptador Dart isolado do Web Service oficial do CFM, com contrato injetável, mapeamento de estados e testes com transporte/fake; sem conectar a rota HTTP da API nesta fatia.

## Propriedade Exclusiva

Pode editar somente:

- `backend/lib/consulta_cfm.dart` (novo)
- `backend/test/consulta_cfm_test.dart` (novo)
- `backend/pubspec.yaml` apenas se Context7 e a implementação demonstrarem uma dependência indispensável, aprovada e validada

Não edite `validador_api.dart`, `bin/server.dart`, README, frontend ou variáveis de ambiente locais.

## Contrato Compartilhado Com WF04

Exponha tipos públicos pequenos, documentados por nomes claros:

- `abstract interface class ConsultaCfm` com consulta assíncrona por `crm` e `uf`.
- `EstadoConsultaCfm`: `conformeDados`, `naoEncontrado`, `naoVerificado`, `falhaConsulta`.
- Resultado imutável com estado e, quando presentes, `crm`, `uf`, `nome`, `situacao`, `tipoInscricao`, `dataAtualizacao`, `especialidade`.
- Implementação concreta padrão `ConsultaCfmSoap`; construtor permite injetar transporte e configuração de teste.

Alinhe nomes/serialização com o contrato do plano antes de congelar a API. Não acrescente credencial no request do cliente Flutter.

## Pré-condições E Portões

- Siga `.agents/AGENTS.md` e a seção de integração/portões de `debug/KAN-07/PLANO.md`.
- SDK backend é Dart `>=3.3.0 <4.0.0`; examine `backend/pubspec.yaml` e padrões Dio/HTTP já usados antes de decidir transporte.
- Context7 antes de implementar qualquer decisão sobre `dart:io`, Dio, parser XML/SOAP, TLS, timeout ou dependência. No backend atual não há pacote `xml`; não presuma que dependência frontend esteja disponível no backend. Sem evidência documental/compatibilidade, não adicione pacote.
- G0 bloqueia chamada real até contrato do CFM confirmado (SOAP 1.1, namespace/envelope, códigos de erro, CRM, UF e situação). G1: sem chave real, teste fake pode avançar; teste manual real fica pendente.
- `CFM_WS_CHAVE` é lida apenas no backend em runtime. Ausente/inválida é falha técnica. Nunca registre chave, envelope, corpo completo, CRM ou nome em logs.

## Execução

1. Leia os helpers HTTP, logging, testes e configuração atuais do backend. Consulte documentação oficial/Context7 para cada API usada; não assuma TLS 1.2 ou parsing por regex.
2. Implemente `Consultar` no endpoint especificado pelo plano, timeout explícito, HTTPS/TLS conforme contrato confirmado e leitura de `codigoErro` mesmo quando HTTP for 200.
3. Mapeie `8101` para `naoEncontrado` somente após decisão aberta confirmada; 3010/4020/2010/2030/2040, erro HTTP, conexão/TLS, timeout, SOAP Fault, resposta inválida e chave ausente/inválida para `falhaConsulta`. Resposta executada mas insuficiente para classificar fica `naoVerificado`.
4. Validar CRM numérico/UF e conferir que o CFM devolveu exatamente a chave solicitada antes de expor dados. Preservar estado conclusivo versus inconclusivo conforme plano.
5. Testar sucesso, chave ausente, códigos de negócio no HTTP 200, SOAP Fault, corpo inválido, erro HTTP, timeout e garantia de que logs não contêm chave/envelope. Use fake, sem rede real.

## Aceitação E Limites

- `dart test` dos testes do cliente e `dart analyze` passam em `backend/`.
- Interface e nomes públicos estão documentados no teste e são o contrato consumido pelo WF04.
- Até 500 linhas alteradas de código de produção, sem contar testes. Se for necessário exceder, pare e proponha fatia nova; não comprima lógica crítica.
- Revise e audite o diff real via Context7; confirme que dependências/secrets não foram adicionados indevidamente.

## Encerramento

Após validação e higiene do worktree, finalize invocando o comando abaixo. Sem chave CFM, deixe a verificação real explicitamente pendente; não invente sucesso. Se já satisfeito, não crie commit vazio.

`/simple-commit`
