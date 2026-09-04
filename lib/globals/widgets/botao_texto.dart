import 'package:flutter/material.dart';

class BotaoTexto extends StatelessWidget {
  const BotaoTexto({
    super.key,
    required this.rotulo,
    required this.onPressed,
  });

  final String rotulo;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: SelectableText(rotulo),
    );
  }
}
