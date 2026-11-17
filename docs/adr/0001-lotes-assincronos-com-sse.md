# Lotes assíncronos com SSE

Com 12 usuários, o processamento síncrono de um lote de 300 itens passa dos
30 s de `receiveTimeout` do front e o limite de um lote por processo fazia todos
os demais receberem 429. Decidimos que `POST /api/lotes` cria uma execução e
responde 202, e que o progresso e o resultado são entregues por SSE em
`GET /api/lotes/{id}/eventos`, com replay por `desde` enquanto a execução está
ativa. O SSE é consumido por `fetch` + `ReadableStream` no Flutter Web porque o
adaptador web do Dio usa XHR e não entrega chunks.

## Consequences

- O contrato quebra e exige deploy coordenado do backend e do front.
- O resultado não é retido depois do fim; recarregar a página perde o lote.
- Após a execução ser descartada, repetir a mesma chave cria nova execução e
  pode duplicar consultas; esse risco é aceito para evitar retenção de resultados.
- Sem assinantes por 30 s, a execução cancela fila e chamadas Dio em andamento
  com `CancelToken` por execução. O cancelamento libera recursos locais, mas não
  garante que o portal interrompa uma operação já recebida; chamadas canceladas
  não são repetidas.
- Cloudflare/Render exigem heartbeat e `X-Accel-Buffering: no` para não
  bufferizar o stream.
