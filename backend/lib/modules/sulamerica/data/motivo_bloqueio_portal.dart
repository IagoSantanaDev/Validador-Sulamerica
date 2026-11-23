/// Causa de bloqueio global do portal.
///
/// Todo motivo listado aqui é elegível para abrir o disjuntor. `chave` viaja
/// no contrato HTTP e `codigo` é o rótulo curto exibido ao usuário.
enum MotivoBloqueioPortal {
  limitePortal(
    'limite_portal',
    '429',
    'Limite de consultas do portal atingido (429)',
  ),
  rejeicaoF5('rejeicao_f5', 'F5', 'Portal bloqueou a consulta (F5)'),
  portalIndisponivel(
    'portal_indisponivel',
    '5xx',
    'Portal temporariamente indisponível',
  ),
  falhaRede('falha_rede', 'REDE', 'Falha de comunicação com o portal'),
  sessaoRejeitada(
    'sessao_rejeitada',
    '401/403',
    'Sessão do portal rejeitada (401/403)',
  ),
  respostaInesperada(
    'resposta_inesperada',
    'RESP',
    'Resposta inesperada do portal',
  );

  const MotivoBloqueioPortal(this.chave, this.codigo, this.mensagem);

  final String chave;
  final String codigo;
  final String mensagem;

  static MotivoBloqueioPortal? deChave(String? chave) {
    for (final MotivoBloqueioPortal motivo in values) {
      if (motivo.chave == chave) return motivo;
    }
    return null;
  }
}
