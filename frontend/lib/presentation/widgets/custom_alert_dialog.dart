import 'package:flutter/material.dart';

class CustomAlertDialog extends StatelessWidget {
  final String titulo;
  final String mensaje;
  final String textoBotonPositivo;
  final String? textoBotonNegativo;
  final Function() onPressedPositivo;
  final Function()? onPressedNegativo;
  final IconData? icono;
  final Color? colorIcono;

  const CustomAlertDialog({
    Key? key,
    required this.titulo,
    required this.mensaje,
    this.textoBotonPositivo = 'Aceptar',
    this.textoBotonNegativo,
    required this.onPressedPositivo,
    this.onPressedNegativo,
    this.icono,
    this.colorIcono,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          if (icono != null) ...[
            Icon(icono, color: colorIcono),
            const SizedBox(width: 8),
          ],
          Text(titulo),
        ],
      ),
      content: Text(mensaje),
      actions: [
        if (textoBotonNegativo != null)
          TextButton(
            onPressed:
                onPressedNegativo ?? () => Navigator.of(context).pop(false),
            child: Text(textoBotonNegativo!),
          ),
        TextButton(
          onPressed: onPressedPositivo,
          child: Text(textoBotonPositivo),
        ),
      ],
    );
  }

  // Método estático para mostrar el diálogo fácilmente
  static Future<bool?> mostrar({
    required BuildContext context,
    required String titulo,
    required String mensaje,
    String textoBotonPositivo = 'Aceptar',
    String? textoBotonNegativo,
    Function()? onPressedPositivo,
    Function()? onPressedNegativo,
    IconData? icono,
    Color? colorIcono,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => CustomAlertDialog(
        titulo: titulo,
        mensaje: mensaje,
        textoBotonPositivo: textoBotonPositivo,
        textoBotonNegativo: textoBotonNegativo,
        onPressedPositivo:
            onPressedPositivo ?? () => Navigator.of(context).pop(true),
        onPressedNegativo: onPressedNegativo,
        icono: icono,
        colorIcono: colorIcono,
      ),
    );
  }
}
