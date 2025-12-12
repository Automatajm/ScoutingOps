import 'package:flutter/material.dart';

class FormFields {
  // Widget para campo de formulario
  static Widget buildFormField({
    required String label,
    required String hint,
    TextEditingController? controller,
    bool enabled = true,
    bool required = false,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    Function()? onTap,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF505050),
              ),
            ),
            if (required)
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.red.shade700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: maxLines > 1 ? null : 40,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            readOnly: readOnly,
            maxLines: maxLines,
            keyboardType: keyboardType,
            onTap: onTap,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: InputBorder.none,
              fillColor: enabled ? Colors.white : Colors.grey[100],
              filled: true,
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // Widget para construir un campo numérico
  static Widget buildNumberField({
    required String label,
    required String hint,
    TextEditingController? controller,
    bool required = false,
    bool readOnly = false,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF505050),
              ),
            ),
            if (required)
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.red.shade700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 40,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
            color: readOnly
                ? Colors.grey.shade100
                : Colors.white, // ✅ Fondo gris si bloqueado
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            readOnly: readOnly,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: InputBorder.none,
              fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
              filled: true,
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // Widget para campos de selección (dropdown)
  static Widget buildDropdownField({
    required String label,
    required String hint,
    required List<String> options,
    String? value,
    Function(String?)? onChanged,
    bool required = false,
    bool readOnly = false, // ✅ NUEVO parámetro
  }) {
    // Si el valor seleccionado no está en las opciones, lo establecemos a null
    if (value != null && !options.contains(value)) {
      value = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF505050),
              ),
            ),
            if (required)
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.red.shade700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(
                color: readOnly ? Colors.grey.shade300 : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
            color: readOnly
                ? Colors.grey.shade100
                : Colors.white, // ✅ Fondo gris si bloqueado
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              hint: Text(
                hint,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13,
                ),
              ),
              items: options.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
              onChanged:
                  readOnly ? null : onChanged, // ✅ Deshabilitar si readOnly
              icon: Icon(Icons.arrow_drop_down,
                  color:
                      readOnly ? Colors.grey.shade400 : Colors.grey.shade600),
              disabledHint: value != null
                  ? Text(value)
                  : null, // ✅ Mostrar valor actual aunque esté deshabilitado
            ),
          ),
        ),
      ],
    );
  }
}
