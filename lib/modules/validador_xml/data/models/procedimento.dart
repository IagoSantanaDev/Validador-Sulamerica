/// Representa um procedimento executado dentro de uma guia TISS.
class Procedimento {
  const Procedimento({
    required this.codigo,
    required this.quantidade,
  });

  final String codigo;
  final int quantidade;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Procedimento &&
          runtimeType == other.runtimeType &&
          codigo == other.codigo &&
          quantidade == other.quantidade;

  @override
  int get hashCode => codigo.hashCode ^ quantidade.hashCode;

  @override
  String toString() => 'Procedimento($codigo x$quantidade)';
}
