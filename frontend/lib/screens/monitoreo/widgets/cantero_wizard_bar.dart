import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget que muestra la barra de navegación del wizard de canteros
/// Se ubica entre la barra de sincronización y el formulario
class CanteroWizardBar extends StatelessWidget {
  /// Rango de canteros (ej: "4-8")
  final String canterosRange;

  /// Cantero actual en la iteración
  final int canteroActual;

  /// Total de canteros en el rango
  final int totalCanteros;

  /// Primer cantero del rango
  final int canteroInicio;

  /// Último cantero del rango
  final int canteroFin;

  /// Si el wizard está activo (rango > 1 cantero)
  final bool isWizardActive;

  /// Si el rango ya fue bloqueado (no se puede editar)
  final bool isRangeLocked;

  /// Estado del formulario: 'clean', 'dirty', 'post_partial'
  final String formState;

  /// Información del lote/casa actual
  final String? loteInfo;
  final String? casaInfo;

  /// Callbacks para navegación de canteros
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onSkip;
  final VoidCallback? onFinish;
  final Function(String)? onRangeChanged;

  /// Si puede navegar entre canteros
  final bool canGoPrevious;
  final bool canGoNext;

  // ✅ NUEVO: Navegación de parciales dentro del mismo cantero
  final String? parcialInfo;
  final bool canteroTieneDatos;
  final VoidCallback? onParcialPrevious;
  final VoidCallback? onParcialNext;
  final bool canParcialPrevious;
  final bool canParcialNext;
  final bool isEditingParcial; // true si está editando un parcial existente

  const CanteroWizardBar({
    Key? key,
    required this.canterosRange,
    required this.canteroActual,
    required this.totalCanteros,
    required this.canteroInicio,
    required this.canteroFin,
    required this.isWizardActive,
    required this.isRangeLocked,
    required this.formState,
    this.loteInfo,
    this.casaInfo,
    this.onPrevious,
    this.onNext,
    this.onSkip,
    this.onFinish,
    this.onRangeChanged,
    this.canGoPrevious = false,
    this.canGoNext = true,
    // Nuevos parámetros
    this.parcialInfo,
    this.canteroTieneDatos = false,
    this.onParcialPrevious,
    this.onParcialNext,
    this.canParcialPrevious = false,
    this.canParcialNext = false,
    this.isEditingParcial = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Si el wizard no está activo, no mostrar nada
    if (!isWizardActive) {
      return const SizedBox.shrink();
    }

    final bool isLastCantero = canteroActual == canteroFin;
    final int posicionActual = canteroActual - canteroInicio + 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.indigo.shade200, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila superior: Info del lote y progreso
          Row(
            children: [
              // Icono del wizard
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.route,
                  color: Colors.indigo.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Info del lote/casa
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wizard de Canteros',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade800,
                      ),
                    ),
                    if (loteInfo != null || casaInfo != null)
                      Text(
                        '${casaInfo ?? ''} ${loteInfo != null ? '• Lote $loteInfo' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.indigo.shade600,
                        ),
                      ),
                  ],
                ),
              ),

              // Indicador de progreso
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Cantero $posicionActual de $totalCanteros',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Barra de progreso visual
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: posicionActual / totalCanteros,
              backgroundColor: Colors.indigo.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo.shade600),
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 12),

          // ✅ NUEVO: Navegación de parciales (si el cantero tiene datos)
          if (canteroTieneDatos && parcialInfo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isEditingParcial
                    ? Colors.amber.shade50
                    : Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isEditingParcial
                      ? Colors.amber.shade300
                      : Colors.purple.shade200,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icono que indica si está editando o es nuevo
                  Icon(
                    isEditingParcial ? Icons.edit : Icons.add_circle_outline,
                    size: 16,
                    color: isEditingParcial
                        ? Colors.amber.shade700
                        : Colors.purple.shade700,
                  ),
                  const SizedBox(width: 8),
                  // Botón parcial anterior
                  InkWell(
                    onTap: canParcialPrevious ? onParcialPrevious : null,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: canParcialPrevious
                            ? (isEditingParcial
                                ? Colors.amber.shade100
                                : Colors.purple.shade100)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios,
                        size: 14,
                        color: canParcialPrevious
                            ? (isEditingParcial
                                ? Colors.amber.shade700
                                : Colors.purple.shade700)
                            : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Información del parcial con indicador de estado
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        parcialInfo!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isEditingParcial
                              ? Colors.amber.shade700
                              : Colors.purple.shade700,
                        ),
                      ),
                      if (isEditingParcial)
                        Text(
                          '(Editando)',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.amber.shade600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // Botón parcial siguiente / nuevo
                  InkWell(
                    onTap: onParcialNext,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isEditingParcial
                            ? Colors.amber.shade100
                            : Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: isEditingParcial
                            ? Colors.amber.shade700
                            : Colors.purple.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Fila inferior: Botones de navegación
          Row(
            children: [
              // Botón Anterior
              _buildNavigationButton(
                icon: Icons.chevron_left,
                label: 'Anterior',
                onPressed: canGoPrevious ? onPrevious : null,
                isEnabled: canGoPrevious,
              ),

              const SizedBox(width: 8),

              // Botón Saltar (con indicador de estado)
              _buildSkipButton(context),

              const Spacer(),

              // Botón Siguiente o Finalizar
              isLastCantero
                  ? _buildFinishButton()
                  : _buildNavigationButton(
                      icon: Icons.chevron_right,
                      label: 'Siguiente',
                      onPressed: canGoNext ? onNext : null,
                      isEnabled: canGoNext,
                      isPrimary: true,
                      iconAtEnd: true,
                    ),
            ],
          ),

          // Indicador de estado del formulario
          if (formState != 'clean')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildFormStateIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildNavigationButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool isEnabled,
    bool isPrimary = false,
    bool iconAtEnd = false,
  }) {
    final buttonStyle = isPrimary
        ? ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo.shade600,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade500,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: Colors.indigo.shade700,
            disabledForegroundColor: Colors.grey.shade400,
            side: BorderSide(
              color: isEnabled ? Colors.indigo.shade300 : Colors.grey.shade300,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          );

    final iconWidget = Icon(icon, size: 18);
    final labelWidget = Text(label, style: const TextStyle(fontSize: 13));

    final children = iconAtEnd
        ? [labelWidget, const SizedBox(width: 4), iconWidget]
        : [iconWidget, const SizedBox(width: 4), labelWidget];

    if (isPrimary) {
      return ElevatedButton(
        onPressed: onPressed,
        style: buttonStyle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      );
    } else {
      return OutlinedButton(
        onPressed: onPressed,
        style: buttonStyle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      );
    }
  }

  Widget _buildSkipButton(BuildContext context) {
    Color buttonColor;
    String tooltip;

    switch (formState) {
      case 'dirty':
        buttonColor = Colors.orange.shade600;
        tooltip = 'Hay datos sin guardar';
        break;
      case 'post_partial':
        buttonColor = Colors.purple.shade600;
        tooltip = 'Usó guardado parcial';
        break;
      default:
        buttonColor = Colors.grey.shade600;
        tooltip = 'Saltar este cantero';
    }

    return Tooltip(
      message: tooltip,
      child: OutlinedButton.icon(
        onPressed: onSkip,
        icon: Icon(Icons.skip_next, size: 18, color: buttonColor),
        label: Text(
          'Saltar',
          style: TextStyle(fontSize: 13, color: buttonColor),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: buttonColor.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildFinishButton() {
    return ElevatedButton.icon(
      onPressed: onFinish,
      icon: const Icon(Icons.check_circle, size: 18),
      label: const Text('Finalizar', style: TextStyle(fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildFormStateIndicator() {
    IconData icon;
    String message;
    Color color;

    switch (formState) {
      case 'dirty':
        icon = Icons.edit_note;
        message = 'Tiene datos sin guardar';
        color = Colors.orange.shade700;
        break;
      case 'post_partial':
        icon = Icons.save_alt;
        message = 'Guardado parcial realizado - puede agregar más plagas';
        color = Colors.purple.shade700;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget para editar el rango de canteros (antes de iniciar el wizard)
class CanteroRangeEditor extends StatefulWidget {
  final String initialRange;
  final bool isLocked;
  final Function(String) onRangeChanged;
  final String? errorMessage;

  const CanteroRangeEditor({
    Key? key,
    required this.initialRange,
    required this.isLocked,
    required this.onRangeChanged,
    this.errorMessage,
  }) : super(key: key);

  @override
  State<CanteroRangeEditor> createState() => _CanteroRangeEditorState();
}

class _CanteroRangeEditorState extends State<CanteroRangeEditor> {
  late TextEditingController _controller;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialRange);
  }

  @override
  void didUpdateWidget(CanteroRangeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRange != widget.initialRange) {
      _controller.text = widget.initialRange;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Valida el formato del rango "X-Y" o número único "X"
  String? _validateRange(String value) {
    if (value.isEmpty) {
      return 'Ingrese el rango de canteros';
    }

    final trimmed = value.trim();

    // Aceptar número único
    if (!trimmed.contains('-')) {
      final numero = int.tryParse(trimmed);
      if (numero == null) {
        return 'Use solo números';
      }
      if (numero < 1 || numero > 110) {
        return 'Debe ser entre 1 y 110';
      }
      return null; // Válido
    }

    // Formato con guión
    final parts = trimmed.split('-');
    if (parts.length != 2) {
      return 'Formato: inicio-fin (ej: 1-10) o número único (ej: 4)';
    }

    final inicio = int.tryParse(parts[0].trim());
    final fin = int.tryParse(parts[1].trim());

    if (inicio == null || fin == null) {
      return 'Use solo números (ej: 4-8)';
    }

    if (inicio < 1 || inicio > 110) {
      return 'Inicio debe ser entre 1 y 110';
    }

    if (fin < 1 || fin > 110) {
      return 'Fin debe ser entre 1 y 110';
    }

    if (inicio > fin) {
      return 'Inicio no puede ser mayor que fin';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final displayError = widget.errorMessage ?? _localError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Campo de texto para el rango
            Expanded(
              child: TextFormField(
                controller: _controller,
                enabled: !widget.isLocked,
                decoration: InputDecoration(
                  labelText: 'Canteros (rango)',
                  hintText: 'Ej: 4 o 1-10',
                  helperText: widget.isLocked
                      ? '🔒 Bloqueado durante iteración'
                      : 'Formato: número único (4) o rango (1-10)',
                  errorText: displayError,
                  prefixIcon: Icon(
                    widget.isLocked ? Icons.lock : Icons.edit,
                    size: 20,
                    color: widget.isLocked ? Colors.grey : Colors.indigo,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor:
                      widget.isLocked ? Colors.grey.shade100 : Colors.white,
                ),
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
                  LengthLimitingTextInputFormatter(7), // "110-110"
                ],
                onChanged: (value) {
                  final error = _validateRange(value);
                  setState(() {
                    _localError = error;
                  });
                  if (error == null) {
                    widget.onRangeChanged(value);
                  }
                },
              ),
            ),

            // Indicador visual del rango
            if (_controller.text.isNotEmpty && _localError == null)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: _buildRangePreview(),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildRangePreview() {
    final parser = CanteroRangeParser.parse(_controller.text);

    if (!parser.isValid) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Column(
        children: [
          Text(
            '${parser.total}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade700,
            ),
          ),
          Text(
            parser.isSingleCantero ? 'cantero' : 'canteros',
            style: TextStyle(
              fontSize: 11,
              color: Colors.indigo.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Clase utilitaria para parsear rangos de canteros
/// ✅ ACEPTA: "4-8" o "4" (número único)
/// ✅ NORMALIZA: "4" → "4-4" (formato estándar)
class CanteroRangeParser {
  final int inicio;
  final int fin;
  final int total;
  final bool isValid;
  final String? error;
  final String? normalizedRange; // ✅ NUEVO: Formato normalizado "X-X"

  CanteroRangeParser._({
    required this.inicio,
    required this.fin,
    required this.total,
    required this.isValid,
    this.error,
    this.normalizedRange,
  });

  /// Parsea un rango en formato "X-Y" o número único "X"
  /// ✅ MEJORA: Acepta ambos formatos y normaliza a "X-X"
  factory CanteroRangeParser.parse(String? range) {
    if (range == null || range.isEmpty) {
      return CanteroRangeParser._(
        inicio: 0,
        fin: 0,
        total: 0,
        isValid: false,
        error: 'Rango vacío',
      );
    }

    final trimmed = range.trim();

    // ✅ NUEVO: Detectar si es un número único (sin guión)
    if (!trimmed.contains('-')) {
      final numero = int.tryParse(trimmed);

      if (numero == null) {
        return CanteroRangeParser._(
          inicio: 0,
          fin: 0,
          total: 0,
          isValid: false,
          error: 'Valor no numérico',
        );
      }

      if (numero < 1 || numero > 110) {
        return CanteroRangeParser._(
          inicio: numero,
          fin: numero,
          total: 0,
          isValid: false,
          error: 'Fuera de rango (1-110)',
        );
      }

      // ✅ Número único válido → convertir a formato "X-X"
      return CanteroRangeParser._(
        inicio: numero,
        fin: numero,
        total: 1,
        isValid: true,
        normalizedRange: '$numero-$numero', // ✅ Formato normalizado
      );
    }

    // Formato con guión "X-Y"
    final parts = trimmed.split('-');
    if (parts.length != 2) {
      return CanteroRangeParser._(
        inicio: 0,
        fin: 0,
        total: 0,
        isValid: false,
        error: 'Formato inválido',
      );
    }

    final inicio = int.tryParse(parts[0].trim());
    final fin = int.tryParse(parts[1].trim());

    if (inicio == null || fin == null) {
      return CanteroRangeParser._(
        inicio: 0,
        fin: 0,
        total: 0,
        isValid: false,
        error: 'Valores no numéricos',
      );
    }

    if (inicio > fin) {
      return CanteroRangeParser._(
        inicio: inicio,
        fin: fin,
        total: 0,
        isValid: false,
        error: 'Inicio mayor que fin',
      );
    }

    if (inicio < 1 || fin > 110) {
      return CanteroRangeParser._(
        inicio: inicio,
        fin: fin,
        total: 0,
        isValid: false,
        error: 'Fuera de rango (1-110)',
      );
    }

    return CanteroRangeParser._(
      inicio: inicio,
      fin: fin,
      total: fin - inicio + 1,
      isValid: true,
      normalizedRange: '$inicio-$fin', // ✅ Formato normalizado
    );
  }

  /// Verifica si el rango contiene un solo cantero (sin wizard)
  bool get isSingleCantero => total == 1;

  /// Genera lista de canteros en el rango
  List<int> get canterosList {
    if (!isValid) return [];
    return List.generate(total, (i) => inicio + i);
  }
}
