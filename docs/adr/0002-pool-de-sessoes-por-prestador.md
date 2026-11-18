# Pool de sessões do portal por prestador

Cada login independente criava uma sessão do portal, e lotes grandes abriam
sessões extras. Sob concorrência, isso causava evicção e logins repetidos.
Decidimos manter um pool limitado de sessões por identificador, criadas sob
demanda e compartilhadas pelas sessões lógicas. O agendador escolhe primeiro
uma sessão autenticada menos ocupada; elegibilidades permanecem serializadas
por sessão, e consultas de senha podem usar concorrência limitada. Resultados
de consulta são tipados por chamada, e falhas transitórias de transporte podem
ser repetidas sem tratar rejeições HTTP como falha de rede.

## Consequences

- Usuários do mesmo identificador dividem a capacidade e o estado de sessão do
  pool.
- Uma sessão expirada afeta chamadas que a utilizam; coalescer a renovação por
  geração evita logins concorrentes e inconsistência dos cookies.
- O limite por identificador é fixo na instância. Réplicas horizontais ou
  estado compartilhado ficam fora desta decisão.
