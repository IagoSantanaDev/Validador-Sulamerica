# Lotes assíncronos com SSE

Com 12 usuários, um lote síncrono poderia exceder o timeout do front, enquanto
uma fila global única causava rejeições mesmo quando havia capacidade para
outras contas. Decidimos aceitar lotes de forma assíncrona e publicar progresso
e resultado por SSE enquanto a execução estiver ativa. A capacidade é limitada
no processo e o agendamento alterna entre identificadores e lotes, para que
uma conta com mais trabalho não monopolize as sessões compartilhadas.

## Consequences

- O contrato quebra e exige deploy coordenado do backend e do front.
- A capacidade é limitada a 24 execuções na instância; não há garantia de
  continuidade depois de reinício, pois o estado permanece em memória.
- O resultado não é retido depois do fim; recarregar a página perde o lote.
- Após a execução ser descartada, repetir a mesma chave cria nova execução e
  pode duplicar consultas; esse risco é aceito para evitar retenção de resultados.
- Sem assinantes por 30 s, a execução cancela fila e chamadas Dio em andamento
  com `CancelToken` por execução. O cancelamento libera recursos locais, mas não
  garante que o portal interrompa uma operação já recebida; chamadas canceladas
  não são repetidas.
- Cloudflare/Render exigem heartbeat e `X-Accel-Buffering: no` para não
  bufferizar o stream.
- O navegador não retoma uma execução após recarga. Em caso de interrupção do
  stream, a aplicação tenta reconectar com o último evento visto e depois deixa
  consultas não resolvidas disponíveis para retentativa manual.
