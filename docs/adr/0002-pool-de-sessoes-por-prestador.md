# Pool de sessões do portal por prestador

Cada login criava uma sessão do portal só para aquele token, e lotes grandes
abriam até 9 sessões extras. Com 12 usuários e teto de 10 sessões, isso gerava
evicção em cascata e logins repetidos. Como o cenário usa exatamente dois
identificadores, com um trio de credenciais por prestador, decidimos manter um
pool de 4 sessões por identificador (8 no total), criadas sob demanda e
compartilhadas pelos usuários daquele prestador, com elegibilidade serial por
sessão e senhas até 3 em paralelo.

## Consequences

- Todos os usuários do mesmo identificador dividem a capacidade do pool.
- Uma sessão expirada afeta todos que a usam; a renovação é feita uma vez e
  protegida por trava.
- O teto de 4 é empírico: se o portal rejeitar concorrência, ele precisa cair.
