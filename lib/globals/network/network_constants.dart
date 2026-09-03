/// Timeouts centralizados do cliente HTTP — sem magic numbers espalhados.
class NetworkConstants {
  const NetworkConstants._();

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 20);
}
