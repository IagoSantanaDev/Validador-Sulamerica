/// Valores estáticos dos formulários Lumis usados por [SulAmericaService].
///
/// Copiados diretamente dos formulários atuais do portal — não são
/// segredos, apenas identificadores de formulário (destId, lumII etc.).
/// Credenciais de login (code/user/senha) NUNCA ficam aqui: são passadas
/// em tempo de execução para `SulAmericaService.login()`.
class SulAmericaCampos {
  const SulAmericaCampos._();

  /// A URL raiz (sem subdomínio) NÃO deve ser usada como destino do POST —
  /// gera ERR_CERT_COMMON_NAME_INVALID. O destino real de cada formulário
  /// é a própria lumFormAction abaixo (subdomínio saude. + lumPageId).
  static const Map<String, String> login = {
    'destId': '8A61890A697C8A4C01697C9D3DE0250E',
    'destType': 'lumII',
    'lumFromForm': 'Form_8A61890A697C8A4C01697C9D3DE0250E',
    'lumFormAction': 'https://saude.sulamericaseguros.com.br/main.jsp'
        '?lumPageId=8A61898253CE1C780153D20B7FF82329'
        '&lumA=1'
        '&lumII=8A61890A697C8A4C01697C9D3DE0250E',
    'doui_processActionId': 'loginPrestador',
    'doui_fromForm': 'Form_8A61890A697C8A4C01697C9D3DE0250E',
    'lumII': '8A61890A697C8A4C01697C9D3DE0250E',
  };

  static const Map<String, String> consulta = {
    'destId': '8A61F4123F589847013F590540AE113E',
    'destType': 'lumII',
    'lumFromForm': 'Form_8A61F4123F589847013F590540AE113E',
    'lumFormAction': 'https://saude.sulamericaseguros.com.br/main.jsp'
        '?lumPageId=8A61F4123F396827013F39A6986109F9'
        '&lumA=1'
        '&lumII=8A61F4123F589847013F590540AE113E',
    'doui_processActionId': 'submitForm',
    'doui_fromForm': 'Form_8A61F4123F589847013F590540AE113E',
    'lumII': '8A61F4123F589847013F590540AE113E',
  };
}
