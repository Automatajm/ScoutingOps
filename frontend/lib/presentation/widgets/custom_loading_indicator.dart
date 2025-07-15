import 'package:flutter/material.dart';

class CustomLoadingIndicator extends StatelessWidget {
  final String mensaje;

  const CustomLoadingIndicator({
    Key? key,
    this.mensaje = 'Cargando...',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(mensaje, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
