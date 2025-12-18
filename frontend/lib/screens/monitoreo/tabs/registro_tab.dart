import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/monitoreo_model.dart';
import '../utils/constants.dart';
import '../utils/nivel_calculator.dart';
import '../widgets/form_fields.dart';
import '../widgets/responsive_card.dart';
import '../widgets/cantero_wizard_bar.dart';
import '../widgets/searchable_variedad_selector.dart';

class RegistroTab extends StatefulWidget {
  final Monitoreo? currentMonitoreo;
  final bool isEditing;
  final bool isCreatingNew;
  final bool isSubmitting;
  final String errorMessage;
  final bool isManualEntry;

  // Controladores
  final TextEditingController codigoLoteController;
  final TextEditingController casaController;
  final TextEditingController canteroController;
  final TextEditingController responsableController;
  final TextEditingController comentariosController;
  final TextEditingController cantidadController;
  final TextEditingController cantidadBotadaController;
  final TextEditingController muestra1Controller;
  final TextEditingController muestra2Controller;
  final TextEditingController muestra3Controller;

  final TextEditingController? canterosRangeController;

  // Valores seleccionados
  final String? selectedCasa;
  final String? selectedVariedad;
  final String? selectedPlaga;
  final String? selectedNivelMuestra1;
  final String? selectedNivelMuestra2;
  final String? selectedNivelMuestra3;

  // Listas para dropdowns
  final List<String> casas;
  final List<String> variedades;
  final List<String> plagas;

  // Límites de niveles
  final int? limiteNivel1;
  final int? limiteNivel2;
  final int? limiteNivel3;

  // Callbacks
  final Function() onSave;
  final Function() onSavePartial;
  final Function() onCancel;
  final Function() onToggleEntryMode;
  final Function() onScanBarcode;
  final Function(String?) onCasaChanged;
  final Function(String?) onVariedadChanged;
  final Function(String?) onPlagaChanged;
  final Function(String?) onNivelMuestra1Changed;
  final Function(String?) onNivelMuestra2Changed;
  final Function(String?) onNivelMuestra3Changed;
  final Function(String) onMuestra1Changed;
  final Function(String) onMuestra2Changed;
  final Function(String) onMuestra3Changed;

  final Function(String)? onCanterosRangeChanged;

  // Propiedad para modo offline
  final bool isOfflineMode;

  // Nueva propiedad para identificar pantallas pequeñas
  final bool isSmallScreen;

  // Indica si estamos en modo parcial
  final bool isInPartialSaveMode;
  final bool isEditingExistingPartial;

  // Set de plagas ya registradas (cantero|variedad|plaga en manual, plaga en auto)
  final Set<String> plagasRegistradas;

  // Set de variedades ya usadas (solo modo manual)
  final Set<String> variedadesUsadas;

  // Propiedades del wizard de canteros
  final bool isWizardActive;
  final bool isWizardRangeLocked;
  final int wizardCanteroActual;
  final int wizardTotalCanteros;

  const RegistroTab({
    Key? key,
    this.currentMonitoreo,
    required this.isEditing,
    required this.isCreatingNew,
    required this.isSubmitting,
    required this.errorMessage,
    required this.isManualEntry,
    required this.codigoLoteController,
    required this.casaController,
    required this.canteroController,
    required this.responsableController,
    required this.comentariosController,
    required this.cantidadController,
    required this.cantidadBotadaController,
    required this.muestra1Controller,
    required this.muestra2Controller,
    required this.muestra3Controller,
    this.canterosRangeController,
    required this.selectedCasa,
    required this.selectedVariedad,
    required this.selectedPlaga,
    required this.selectedNivelMuestra1,
    required this.selectedNivelMuestra2,
    required this.selectedNivelMuestra3,
    required this.casas,
    required this.variedades,
    required this.plagas,
    required this.limiteNivel1,
    required this.limiteNivel2,
    required this.limiteNivel3,
    required this.onSave,
    required this.onSavePartial,
    required this.onCancel,
    required this.onToggleEntryMode,
    required this.onScanBarcode,
    required this.onCasaChanged,
    required this.onVariedadChanged,
    required this.onPlagaChanged,
    required this.onNivelMuestra1Changed,
    required this.onNivelMuestra2Changed,
    required this.onNivelMuestra3Changed,
    required this.onMuestra1Changed,
    required this.onMuestra2Changed,
    required this.onMuestra3Changed,
    this.onCanterosRangeChanged,
    this.isOfflineMode = false,
    this.isSmallScreen = false,
    this.isInPartialSaveMode = false,
    this.isEditingExistingPartial = false,
    this.plagasRegistradas = const {},
    this.variedadesUsadas = const {},
    this.isWizardActive = false,
    this.isWizardRangeLocked = false,
    this.wizardCanteroActual = 0,
    this.wizardTotalCanteros = 0,
  }) : super(key: key);

  @override
  State<RegistroTab> createState() => _RegistroTabState();
}

class _RegistroTabState extends State<RegistroTab> {
  // Estados para secciones colapsables en móvil
  bool _isLoteExpanded = true;
  bool _isMonitoreoExpanded = true;
  bool _isMuestrasExpanded = true;

  // Variable para error de cantero
  String? _canteroError;

  // Error para rango de canteros
  String? _canterosRangeError;

  @override
  Widget build(BuildContext context) {
    // Lista de niveles de muestra manual
    final List<String> nivelesMuestra = ['1', '2', '3'];

    return Container(
      color: MonitoreoStyles.lightGrey,
      padding: EdgeInsets.all(widget.isSmallScreen ? 8 : 16),
      child: widget.isSmallScreen
          ? _buildMobileLayout(nivelesMuestra)
          : _buildDesktopLayout(nivelesMuestra),
    );
  }

  // ✅ NUEVO: Widget para el campo de rango de canteros (SIN barra de progreso duplicada)
  Widget _buildCanterosRangeField() {
    if (widget.canterosRangeController == null) {
      return const SizedBox.shrink();
    }

    final isLocked = widget.isWizardRangeLocked || widget.isInPartialSaveMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: widget.canterosRangeController,
                enabled: !isLocked,
                decoration: InputDecoration(
                  labelText: 'Canteros (rango)',
                  hintText: 'Ej: 1-10',
                  helperText: isLocked
                      ? '🔒 Bloqueado durante iteración'
                      : 'Formato: inicio-fin',
                  helperStyle: TextStyle(
                    color: isLocked
                        ? Colors.orange.shade700
                        : Colors.grey.shade600,
                    fontSize: 11,
                  ),
                  errorText: _canterosRangeError,
                  prefixIcon: Icon(
                    isLocked ? Icons.lock : Icons.edit,
                    size: 20,
                    color: isLocked ? Colors.orange : Colors.indigo,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: isLocked ? Colors.orange.shade50 : Colors.white,
                ),
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
                  LengthLimitingTextInputFormatter(7),
                ],
                onChanged: (value) {
                  final error = _validateCanterosRange(value);
                  setState(() {
                    _canterosRangeError = error;
                  });
                  if (error == null && widget.onCanterosRangeChanged != null) {
                    widget.onCanterosRangeChanged!(value);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            // Campo de cantero actual (siempre readonly)
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: widget.canteroController,
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'Cantero actual',
                  prefixIcon: Icon(
                    Icons.location_on,
                    size: 20,
                    color: Colors.indigo.shade600,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.indigo.shade50,
                ),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade800,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),

        // ❌ BARRA DE PROGRESO DUPLICADA ELIMINADA
        // La barra de progreso ya está en el CanteroWizardBar del header
      ],
    );
  }

  // Validar formato del rango
  String? _validateCanterosRange(String value) {
    if (value.isEmpty) return null;

    final parts = value.split('-');
    if (parts.length != 2) {
      return 'Formato: inicio-fin';
    }

    final inicio = int.tryParse(parts[0].trim());
    final fin = int.tryParse(parts[1].trim());

    if (inicio == null || fin == null) {
      return 'Use solo números';
    }

    if (inicio < 1 || inicio > 110) {
      return 'Inicio: 1-110';
    }

    if (fin < 1 || fin > 110) {
      return 'Fin: 1-110';
    }

    if (inicio > fin) {
      return 'Inicio > fin';
    }

    return null;
  }

  // Layout para pantallas de escritorio
  Widget _buildDesktopLayout(List<String> nivelesMuestra) {
    // Determinar si mostrar el campo de canteros del wizard
    final showWizardFields = widget.canterosRangeController != null &&
        (widget.codigoLoteController.text.isNotEmpty || widget.isManualEntry);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: widget.isSubmitting
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Título
                    Text(
                      widget.isCreatingNew
                          ? 'Nuevo Monitoreo'
                          : 'Editar Monitoreo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: MonitoreoStyles.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ❌ BANNER "MODO SIN CONEXIÓN" ELIMINADO

                    // Mensaje de error si existe
                    if (widget.errorMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.errorMessage,
                          style: TextStyle(color: Colors.red.shade800),
                        ),
                      ),

                    // Toggle automático/manual
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Text(
                            'Modo de entrada:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 16),
                          ToggleButtons(
                            isSelected: [
                              !widget.isManualEntry,
                              widget.isManualEntry
                            ],
                            onPressed: widget.isWizardRangeLocked ||
                                    widget.isInPartialSaveMode
                                ? null
                                : (index) {
                                    widget.onToggleEntryMode();
                                  },
                            borderRadius: BorderRadius.circular(4),
                            children: const [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('Código de barras'),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('Manual'),
                              ),
                            ],
                          ),
                          if (widget.isWizardRangeLocked ||
                              widget.isInPartialSaveMode)
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Tooltip(
                                message:
                                    'El modo está bloqueado durante la iteración',
                                child: Icon(
                                  Icons.lock,
                                  size: 18,
                                  color: Colors.orange.shade600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sección para información del lote
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Información del lote',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: MonitoreoStyles.primaryColor,
                            ),
                          ),
                          const Divider(height: 24),

                          // Código de lote (con botón de escaneo)
                          if (!widget.isManualEntry)
                            Row(
                              children: [
                                Expanded(
                                  child: FormFields.buildFormField(
                                    label: 'Código de lote',
                                    hint:
                                        'Escanee o ingrese el código del lote',
                                    controller: widget.codigoLoteController,
                                    readOnly: widget.isWizardRangeLocked ||
                                        widget.isInPartialSaveMode,
                                    required: false,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton.icon(
                                  onPressed: (widget.isWizardRangeLocked ||
                                          widget.isInPartialSaveMode)
                                      ? null
                                      : widget.onScanBarcode,
                                  icon: const Icon(Icons.qr_code_scanner),
                                  label: const Text('Escanear'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        MonitoreoStyles.accentColor,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ],
                            ),

                          if (!widget.isManualEntry) const SizedBox(height: 16),

                          // Campo de rango de canteros (si está disponible)
                          if (showWizardFields) ...[
                            _buildCanterosRangeField(),
                            const SizedBox(height: 16),
                          ],

                          // Campos para entrada
                          Row(
                            children: [
                              Expanded(
                                child: FormFields.buildDropdownField(
                                  label: 'Casa',
                                  hint: 'Seleccione casa',
                                  options: widget.casas,
                                  value: widget.selectedCasa,
                                  onChanged: (widget.isWizardRangeLocked ||
                                          widget.isInPartialSaveMode)
                                      ? null
                                      : widget.onCasaChanged,
                                  required: true,
                                  readOnly: widget.isWizardRangeLocked ||
                                      widget.isInPartialSaveMode,
                                ),
                              ),
                              const SizedBox(width: 16),
                              if (!showWizardFields)
                                Expanded(
                                  child: TextFormField(
                                    controller: widget.canteroController,
                                    decoration: InputDecoration(
                                      labelText: 'Cantero * (1-110)',
                                      hintText: 'Número del 1 al 110',
                                      errorText: _canteroError,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(3),
                                    ],
                                    readOnly: widget.isInPartialSaveMode ||
                                        !(widget.isManualEntry ||
                                            widget.codigoLoteController.text
                                                .isNotEmpty),
                                    onChanged: (value) {
                                      if (value.isNotEmpty) {
                                        final numero = int.tryParse(value);
                                        if (numero == null ||
                                            numero < 1 ||
                                            numero > 110) {
                                          setState(() {
                                            _canteroError =
                                                'Debe ser un número entre 1 y 110';
                                          });
                                        } else {
                                          setState(() {
                                            _canteroError = null;
                                          });
                                        }
                                      } else {
                                        setState(() {
                                          _canteroError = null;
                                        });
                                      }
                                    },
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: widget.isManualEntry ||
                                        widget.codigoLoteController.text.isEmpty
                                    ? SearchableVariedadSelector(
                                        label: 'Variedad',
                                        hint: 'Seleccione variedad',
                                        options: widget.variedades,
                                        value: widget.selectedVariedad,
                                        onChanged: widget.onVariedadChanged,
                                        required: true,
                                      )
                                    : FormFields.buildFormField(
                                        label: 'Variedad',
                                        hint: 'Variedad del lote',
                                        controller: TextEditingController(
                                          text: widget.selectedVariedad ?? '',
                                        ),
                                        readOnly: true,
                                        required: true,
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: FormFields.buildFormField(
                                  label: 'Responsable',
                                  hint: 'Responsable del cultivo',
                                  controller: widget.responsableController,
                                  readOnly: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sección para datos de monitoreo
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Datos del monitoreo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: MonitoreoStyles.primaryColor,
                            ),
                          ),
                          const Divider(height: 24),

                          // Selección de plaga
                          FormFields.buildDropdownField(
                            label: 'Plaga',
                            hint: 'Seleccione la plaga',
                            options: widget.plagas,
                            value: widget.selectedPlaga,
                            onChanged: widget.onPlagaChanged,
                            required: true,
                          ),
                          const SizedBox(height: 16),

                          // Indicadores de plagas registradas
                          if (widget.isManualEntry &&
                              widget.isInPartialSaveMode &&
                              widget.plagasRegistradas.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.purple.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          size: 16,
                                          color: Colors.purple.shade800),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Plagas registradas en este cantero:',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.purple.shade800,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ...widget.plagasRegistradas.map((registro) {
                                    final partes = registro.split('|');
                                    if (partes.length == 3) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          '• ${partes[1]} - ${partes[2]}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.purple.shade700,
                                          ),
                                        ),
                                      );
                                    } else {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          '• $registro',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.purple.shade700,
                                          ),
                                        ),
                                      );
                                    }
                                  }).toList(),
                                ],
                              ),
                            ),

                          // Indicadores modo automático
                          if (!widget.isManualEntry &&
                              widget.isInPartialSaveMode &&
                              widget.plagasRegistradas.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.purple.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          size: 16,
                                          color: Colors.purple.shade800),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Plagas registradas en este lote:',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.purple.shade800,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ...widget.plagasRegistradas.map((plaga) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        '• $plaga',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.purple.shade700,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),

                          // Cantidades
                          Row(
                            children: [
                              Expanded(
                                child: FormFields.buildFormField(
                                  label: 'Cantidad observada',
                                  hint: 'Calculada automáticamente',
                                  controller: widget.cantidadController,
                                  readOnly: true,
                                  required: false,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: FormFields.buildNumberField(
                                  label: 'Cantidad eliminada',
                                  hint: 'Ingrese la cantidad',
                                  controller: widget.cantidadBotadaController,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Comentarios
                          FormFields.buildFormField(
                            label: 'Comentarios',
                            hint: 'Ingrese comentarios adicionales',
                            controller: widget.comentariosController,
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Datos de muestras y niveles
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Muestras y niveles',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: MonitoreoStyles.primaryColor,
                            ),
                          ),
                          const Divider(height: 24),

                          // Información sobre niveles
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Información de niveles:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: MonitoreoStyles.primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                    'Nivel 1: Entre 0 y ${widget.limiteNivel1 ?? 10}'),
                                Text(
                                    'Nivel 2: Entre ${widget.limiteNivel1 != null ? widget.limiteNivel1! + 1 : 11} y ${widget.limiteNivel2 ?? 20}'),
                                Text(
                                    'Nivel 3: Mayor a ${widget.limiteNivel2 ?? 20}'),
                              ],
                            ),
                          ),

                          // Muestras
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: FormFields.buildNumberField(
                                  label: 'Muestra 1',
                                  hint: 'Valor numérico',
                                  controller: widget.muestra1Controller,
                                  onChanged: widget.onMuestra1Changed,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: FormFields.buildDropdownField(
                                  label: 'Nivel manual 1',
                                  hint: 'Nivel',
                                  options: nivelesMuestra,
                                  value: widget.selectedNivelMuestra1,
                                  onChanged: widget.muestra1Controller.text
                                          .trim()
                                          .isEmpty
                                      ? null
                                      : widget.onNivelMuestra1Changed,
                                  readOnly: widget.muestra1Controller.text
                                      .trim()
                                      .isEmpty,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: FormFields.buildNumberField(
                                  label: 'Muestra 2',
                                  hint: 'Valor numérico',
                                  controller: widget.muestra2Controller,
                                  onChanged: widget.onMuestra2Changed,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: FormFields.buildDropdownField(
                                  label: 'Nivel manual 2',
                                  hint: 'Nivel',
                                  options: nivelesMuestra,
                                  value: widget.selectedNivelMuestra2,
                                  onChanged: widget.muestra2Controller.text
                                          .trim()
                                          .isEmpty
                                      ? null
                                      : widget.onNivelMuestra2Changed,
                                  readOnly: widget.muestra2Controller.text
                                      .trim()
                                      .isEmpty,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: FormFields.buildNumberField(
                                  label: 'Muestra 3',
                                  hint: 'Valor numérico',
                                  controller: widget.muestra3Controller,
                                  onChanged: widget.onMuestra3Changed,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: FormFields.buildDropdownField(
                                  label: 'Nivel manual 3',
                                  hint: 'Nivel',
                                  options: nivelesMuestra,
                                  value: widget.selectedNivelMuestra3,
                                  onChanged: widget.muestra3Controller.text
                                          .trim()
                                          .isEmpty
                                      ? null
                                      : widget.onNivelMuestra3Changed,
                                  readOnly: widget.muestra3Controller.text
                                      .trim()
                                      .isEmpty,
                                ),
                              ),
                            ],
                          ),

                          // Niveles calculados
                          if (widget.muestra1Controller.text.isNotEmpty ||
                              widget.muestra2Controller.text.isNotEmpty ||
                              widget.muestra3Controller.text.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 16),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.green.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Niveles calculados automáticamente:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: MonitoreoStyles.accentColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (widget.muestra1Controller.text.isNotEmpty)
                                    Text(
                                        'Muestra 1: Nivel ${NivelCalculator.calcularNivelAutomatico(int.tryParse(widget.muestra1Controller.text), widget.limiteNivel1, widget.limiteNivel2)}'),
                                  if (widget.muestra2Controller.text.isNotEmpty)
                                    Text(
                                        'Muestra 2: Nivel ${NivelCalculator.calcularNivelAutomatico(int.tryParse(widget.muestra2Controller.text), widget.limiteNivel1, widget.limiteNivel2)}'),
                                  if (widget.muestra3Controller.text.isNotEmpty)
                                    Text(
                                        'Muestra 3: Nivel ${NivelCalculator.calcularNivelAutomatico(int.tryParse(widget.muestra3Controller.text), widget.limiteNivel1, widget.limiteNivel2)}'),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Botones de acción
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: widget.onCancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade400),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed:
                              widget.isSubmitting ? null : widget.onSavePartial,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE91E63),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            disabledBackgroundColor: Colors.grey.shade400,
                          ),
                          child: Text(widget.isEditingExistingPartial
                              ? 'Editar Parcial'
                              : 'Parcial'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: widget.isSubmitting ? null : widget.onSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MonitoreoStyles.accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            disabledBackgroundColor: Colors.grey.shade400,
                          ),
                          child: Text(
                              widget.isCreatingNew ? 'Guardar' : 'Actualizar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // Layout para pantallas móviles
  Widget _buildMobileLayout(List<String> nivelesMuestra) {
    final showWizardFields = widget.canterosRangeController != null &&
        (widget.codigoLoteController.text.isNotEmpty || widget.isManualEntry);

    return widget.isSubmitting
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Título y controles de modo
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isCreatingNew
                              ? 'Nuevo Monitoreo'
                              : 'Editar Monitoreo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: MonitoreoStyles.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Toggle automático/manual
                        Row(
                          children: [
                            const Text(
                              'Modo:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ToggleButtons(
                                isSelected: [
                                  !widget.isManualEntry,
                                  widget.isManualEntry
                                ],
                                onPressed: (widget.isWizardRangeLocked ||
                                        widget.isInPartialSaveMode)
                                    ? null
                                    : (index) {
                                        widget.onToggleEntryMode();
                                      },
                                borderRadius: BorderRadius.circular(4),
                                constraints: const BoxConstraints(
                                  minHeight: 36,
                                  minWidth: 80,
                                ),
                                children: const [
                                  Text('Código',
                                      style: TextStyle(fontSize: 13)),
                                  Text('Manual',
                                      style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                            if (widget.isWizardRangeLocked ||
                                widget.isInPartialSaveMode)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Icon(
                                  Icons.lock,
                                  size: 16,
                                  color: Colors.orange.shade600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Mensaje de error
                if (widget.errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      widget.errorMessage,
                      style: TextStyle(color: Colors.red.shade800),
                    ),
                  ),

                // ❌ BANNER OFFLINE ELIMINADO EN MOBILE LAYOUT

                // Sección de información del lote (colapsable)
                CollapsibleCard(
                  title: 'Información del lote',
                  initiallyExpanded: _isLoteExpanded,
                  titleColor: MonitoreoStyles.primaryColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Código de lote
                      if (!widget.isManualEntry)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FormFields.buildFormField(
                              label: 'Código de lote',
                              hint: 'Escanee o ingrese el código',
                              controller: widget.codigoLoteController,
                              readOnly: widget.isWizardRangeLocked ||
                                  widget.isInPartialSaveMode,
                              required: false,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: (widget.isWizardRangeLocked ||
                                        widget.isInPartialSaveMode)
                                    ? null
                                    : widget.onScanBarcode,
                                icon:
                                    const Icon(Icons.qr_code_scanner, size: 16),
                                label: const Text('Escanear código'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: MonitoreoStyles.accentColor,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),

                      // Campo de rango de canteros en móvil
                      if (showWizardFields) ...[
                        _buildCanterosRangeField(),
                        const SizedBox(height: 12),
                      ],

                      // Casa
                      FormFields.buildDropdownField(
                        label: 'Casa',
                        hint: 'Seleccione casa',
                        options: widget.casas,
                        value: widget.selectedCasa,
                        onChanged: (widget.isWizardRangeLocked ||
                                widget.isInPartialSaveMode)
                            ? null
                            : widget.onCasaChanged,
                        required: true,
                        readOnly: widget.isWizardRangeLocked ||
                            widget.isInPartialSaveMode,
                      ),
                      const SizedBox(height: 12),

                      // Cantero (solo si no hay wizard)
                      if (!showWizardFields) ...[
                        TextFormField(
                          controller: widget.canteroController,
                          decoration: InputDecoration(
                            labelText: 'Cantero * (1-110)',
                            hintText: 'Número del 1 al 110',
                            errorText: _canteroError,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          readOnly: widget.isInPartialSaveMode ||
                              !(widget.isManualEntry ||
                                  widget.codigoLoteController.text.isNotEmpty),
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              final numero = int.tryParse(value);
                              if (numero == null ||
                                  numero < 1 ||
                                  numero > 110) {
                                setState(() {
                                  _canteroError =
                                      'Debe ser un número entre 1 y 110';
                                });
                              } else {
                                setState(() {
                                  _canteroError = null;
                                });
                              }
                            } else {
                              setState(() {
                                _canteroError = null;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Variedad
                      widget.isManualEntry ||
                              widget.codigoLoteController.text.isEmpty
                          ? SearchableVariedadSelector(
                              label: 'Variedad',
                              hint: 'Seleccione variedad',
                              options: widget.variedades,
                              value: widget.selectedVariedad,
                              onChanged: widget.onVariedadChanged,
                              required: true,
                            )
                          : FormFields.buildFormField(
                              label: 'Variedad',
                              hint: 'Variedad del lote',
                              controller: TextEditingController(
                                text: widget.selectedVariedad ?? '',
                              ),
                              readOnly: true,
                              required: true,
                            ),
                      const SizedBox(height: 12),

                      // Responsable
                      FormFields.buildFormField(
                        label: 'Responsable',
                        hint: 'Responsable del cultivo',
                        controller: widget.responsableController,
                        readOnly: true,
                      ),
                    ],
                  ),
                ),

                // Sección datos del monitoreo (colapsable)
                CollapsibleCard(
                  title: 'Datos del monitoreo',
                  initiallyExpanded: _isMonitoreoExpanded,
                  titleColor: MonitoreoStyles.primaryColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FormFields.buildDropdownField(
                        label: 'Plaga',
                        hint: 'Seleccione la plaga',
                        options: widget.plagas,
                        value: widget.selectedPlaga,
                        onChanged: widget.onPlagaChanged,
                        required: true,
                      ),
                      const SizedBox(height: 12),

                      // Indicadores de plagas registradas
                      if (widget.isInPartialSaveMode &&
                          widget.plagasRegistradas.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.purple.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 14, color: Colors.purple.shade800),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Plagas registradas:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.purple.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ...widget.plagasRegistradas.map((registro) {
                                final partes = registro.split('|');
                                final texto = partes.length == 3
                                    ? '${partes[1]} - ${partes[2]}'
                                    : registro;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    '• $texto',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.purple.shade700),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),

                      FormFields.buildFormField(
                        label: 'Cantidad observada',
                        hint: 'Calculada automáticamente',
                        controller: widget.cantidadController,
                        readOnly: true,
                        required: false,
                      ),
                      const SizedBox(height: 12),

                      FormFields.buildNumberField(
                        label: 'Cantidad eliminada',
                        hint: 'Ingrese la cantidad',
                        controller: widget.cantidadBotadaController,
                      ),
                      const SizedBox(height: 12),

                      FormFields.buildFormField(
                        label: 'Comentarios',
                        hint: 'Comentarios adicionales',
                        controller: widget.comentariosController,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),

                // Sección muestras y niveles (colapsable)
                CollapsibleCard(
                  title: 'Muestras y niveles',
                  initiallyExpanded: _isMuestrasExpanded,
                  titleColor: MonitoreoStyles.primaryColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Muestras
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: FormFields.buildNumberField(
                              label: 'Muestra 1',
                              hint: 'Valor',
                              controller: widget.muestra1Controller,
                              onChanged: widget.onMuestra1Changed,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FormFields.buildDropdownField(
                              label: 'Nivel 1',
                              hint: 'Nivel',
                              options: nivelesMuestra,
                              value: widget.selectedNivelMuestra1,
                              onChanged:
                                  widget.muestra1Controller.text.trim().isEmpty
                                      ? null
                                      : widget.onNivelMuestra1Changed,
                              readOnly:
                                  widget.muestra1Controller.text.trim().isEmpty,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: FormFields.buildNumberField(
                              label: 'Muestra 2',
                              hint: 'Valor',
                              controller: widget.muestra2Controller,
                              onChanged: widget.onMuestra2Changed,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FormFields.buildDropdownField(
                              label: 'Nivel 2',
                              hint: 'Nivel',
                              options: nivelesMuestra,
                              value: widget.selectedNivelMuestra2,
                              onChanged:
                                  widget.muestra2Controller.text.trim().isEmpty
                                      ? null
                                      : widget.onNivelMuestra2Changed,
                              readOnly:
                                  widget.muestra2Controller.text.trim().isEmpty,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: FormFields.buildNumberField(
                              label: 'Muestra 3',
                              hint: 'Valor',
                              controller: widget.muestra3Controller,
                              onChanged: widget.onMuestra3Changed,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FormFields.buildDropdownField(
                              label: 'Nivel 3',
                              hint: 'Nivel',
                              options: nivelesMuestra,
                              value: widget.selectedNivelMuestra3,
                              onChanged:
                                  widget.muestra3Controller.text.trim().isEmpty
                                      ? null
                                      : widget.onNivelMuestra3Changed,
                              readOnly:
                                  widget.muestra3Controller.text.trim().isEmpty,
                            ),
                          ),
                        ],
                      ),

                      // Niveles calculados
                      if (widget.muestra1Controller.text.isNotEmpty ||
                          widget.muestra2Controller.text.isNotEmpty ||
                          widget.muestra3Controller.text.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Niveles automáticos:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: MonitoreoStyles.accentColor,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (widget.muestra1Controller.text.isNotEmpty)
                                Text(
                                    'M1: Nivel ${NivelCalculator.calcularNivelAutomatico(int.tryParse(widget.muestra1Controller.text), widget.limiteNivel1, widget.limiteNivel2)}',
                                    style: const TextStyle(fontSize: 12)),
                              if (widget.muestra2Controller.text.isNotEmpty)
                                Text(
                                    'M2: Nivel ${NivelCalculator.calcularNivelAutomatico(int.tryParse(widget.muestra2Controller.text), widget.limiteNivel1, widget.limiteNivel2)}',
                                    style: const TextStyle(fontSize: 12)),
                              if (widget.muestra3Controller.text.isNotEmpty)
                                Text(
                                    'M3: Nivel ${NivelCalculator.calcularNivelAutomatico(int.tryParse(widget.muestra3Controller.text), widget.limiteNivel1, widget.limiteNivel2)}',
                                    style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Botones de acción
                Card(
                  elevation: 1,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                widget.isSubmitting ? null : widget.onSave,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MonitoreoStyles.accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              disabledBackgroundColor: Colors.grey.shade400,
                            ),
                            child: Text(
                              widget.isCreatingNew ? 'Guardar' : 'Actualizar',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: widget.isSubmitting
                                    ? null
                                    : widget.onSavePartial,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE91E63),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  disabledBackgroundColor: Colors.grey.shade400,
                                ),
                                child: Text(widget.isEditingExistingPartial
                                    ? 'Editar parcial'
                                    : 'Guardar parcial'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: widget.onCancel,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey.shade700,
                                  side: BorderSide(color: Colors.grey.shade400),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: const Text('Cancelar'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
  }
}