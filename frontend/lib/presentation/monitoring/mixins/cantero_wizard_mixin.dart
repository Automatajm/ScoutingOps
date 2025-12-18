import 'package:flutter/material.dart';
import '../../../models/monitoreo_model.dart';
import '../../../screens/monitoreo/utils/constants.dart';

/// Mixin que maneja toda la lógica del wizard de canteros para iteración secuencial
mixin CanteroWizardMixin<T extends StatefulWidget> on State<T> {
  // ===== VARIABLES DEL WIZARD =====
  bool _isWizardActive = false;
  bool _isWizardRangeLocked = false;
  int _wizardCanteroActual = 0;
  int _wizardCanteroInicio = 0;
  int _wizardCanteroFin = 0;
  int _wizardTotalCanteros = 0;
  String _wizardFormState = 'clean';
  Map<int, List<int>> _wizardCanterosMonitoreos = {};
  int _wizardParcialIndex = 0;
  int? _lastCreatedSequence;

  // ===== GETTERS PARA EXPONER ESTADO =====
  bool get isWizardActive => _isWizardActive;
  bool get isWizardRangeLocked => _isWizardRangeLocked;
  int get wizardCanteroActual => _wizardCanteroActual;
  int get wizardCanteroInicio => _wizardCanteroInicio;
  int get wizardCanteroFin => _wizardCanteroFin;
  int get wizardTotalCanteros => _wizardTotalCanteros;
  String get wizardFormState => _wizardFormState;
  Map<int, List<int>> get wizardCanterosMonitoreos => _wizardCanterosMonitoreos;
  int get wizardParcialIndex => _wizardParcialIndex;

  // ===== MÉTODOS ABSTRACTOS (deben implementarse en el State) =====
  
  /// Controlador del campo de cantero
  TextEditingController get canteroController;
  
  /// Controlador del campo de rango de canteros
  TextEditingController get canterosRangeController;
  
  /// Si está en modo entrada manual
  bool get isManualEntry;
  
  /// Campo original de canteros del lote
  String? get loteCanterosOriginal;
  set loteCanterosOriginal(String? value);
  
  /// Datos de monitoreos cargados
  List<Monitoreo> get monitoreoData;
  
  /// Código del lote actual
  String get currentLoteCode;
  
  /// Casa actual
  String get currentCasa;
  
  /// Controladores de formulario
  TextEditingController get codigoLoteController;
  TextEditingController get casaController;
  TextEditingController get comentariosController;
  TextEditingController get cantidadController;
  TextEditingController get cantidadBotadaController;
  TextEditingController get muestra1Controller;
  TextEditingController get muestra2Controller;
  TextEditingController get muestra3Controller;
  
  /// Plaga seleccionada
  String? get selectedPlaga;
  set selectedPlaga(String? value);
  
  /// Niveles de muestra seleccionados
  String? get selectedNivelMuestra1;
  set selectedNivelMuestra1(String? value);
  String? get selectedNivelMuestra2;
  set selectedNivelMuestra2(String? value);
  String? get selectedNivelMuestra3;
  set selectedNivelMuestra3(String? value);
  
  /// Monitoreo actual en edición
  Monitoreo? get currentMonitoreo;
  set currentMonitoreo(Monitoreo? value);
  
  /// Si está editando un parcial existente
  bool get isEditingExistingPartial;
  set isEditingExistingPartial(bool value);
  
  /// Set de plagas registradas en guardado parcial
  Set<String> get plagasRegistradasParcial;
  
  /// Set de variedades usadas en guardado parcial
  Set<String> get variedadesUsadasParcial;
  
  /// Si está en modo guardado parcial
  bool get isInPartialSaveMode;
  set isInPartialSaveMode(bool value);
  
  /// Si el último guardado fue exitoso
  bool get lastSaveSuccess;
  
  /// Método para guardar monitoreo
  Future<void> saveMonitoreo();
  
  /// Método para mostrar mensajes
  void showMessage(String message);
  
  /// Método para cargar datos
  Future<void> loadData();
  
  /// Método para limpiar monitoreo data (campos de plaga/cantidad/comentarios)
  void clearMonitoreoData();
  
  /// Método para preparar datos de navegación
  void prepareNavigationData();

  // ===== INICIALIZACIÓN DEL WIZARD =====
  
  void initWizard(String range) {
    final parser = CanteroRangeParser.parse(range);
    if (!parser.isValid) {
      showMessage('Rango inválido: ${parser.error}');
      return;
    }

    final normalizedRange = parser.normalizedRange ?? range;

    // Si es un solo cantero, no activar wizard
    if (parser.isSingleCantero) {
      setState(() {
        _isWizardActive = false;
        canteroController.text = parser.inicio.toString();
        if (isManualEntry) {
          loteCanterosOriginal = normalizedRange;
        }
      });
      return;
    }

    // Activar wizard para rangos
    setState(() {
      _isWizardActive = true;
      _isWizardRangeLocked = false;
      _wizardCanteroInicio = parser.inicio;
      _wizardCanteroFin = parser.fin;
      _wizardTotalCanteros = parser.total;
      _wizardCanteroActual = parser.inicio;
      _wizardFormState = 'clean';
      _wizardCanterosMonitoreos = {};
      _wizardParcialIndex = 0;
      canteroController.text = parser.inicio.toString();
      canterosRangeController.text = normalizedRange;

      if (isManualEntry) {
        loteCanterosOriginal = normalizedRange;
      }
    });

    _preloadExistingMonitoreos();
  }

  // ===== PRE-CARGA DE MONITOREOS EXISTENTES =====
  
  void _preloadExistingMonitoreos() {
    if (currentLoteCode.isEmpty) return;

    final lote = currentLoteCode;
    final casa = currentCasa;
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final finHoy = inicioHoy.add(const Duration(days: 1));

    // Filtrar monitoreos del día actual
    final monitoreosHoy = monitoreoData.where((m) {
      if (m.pmlt_codigo != lote) return false;
      if (casa.isNotEmpty && m.pmmo_casa != casa) return false;
      if (m.pmmo_fecha == null) return false;
      final fecha = m.pmmo_fecha!;
      return fecha.isAfter(inicioHoy) && fecha.isBefore(finHoy);
    }).toList();

    if (monitoreosHoy.isEmpty) return;

    // Agrupar por cantero
    final Map<int, List<int>> canteroSecuencias = {};
    for (var m in monitoreosHoy) {
      final canteroStr = m.pmmo_cantero;
      if (canteroStr == null) continue;
      final cantero = int.tryParse(canteroStr);
      if (cantero == null) continue;

      if (cantero < _wizardCanteroInicio || cantero > _wizardCanteroFin) continue;

      if (!canteroSecuencias.containsKey(cantero)) {
        canteroSecuencias[cantero] = [];
      }
      if (m.pmmo_secuencia != null) {
        canteroSecuencias[cantero]!.add(m.pmmo_secuencia!);
      }
    }

    if (canteroSecuencias.isNotEmpty) {
      setState(() {
        _wizardCanterosMonitoreos = canteroSecuencias;
      });

      // Cargar monitoreos del cantero actual si existen
      final secuenciasActual = _wizardCanterosMonitoreos[_wizardCanteroActual];
      if (secuenciasActual != null && secuenciasActual.isNotEmpty) {
        _loadWizardCanteroMonitoreos(_wizardCanteroActual, secuenciasActual);
      }
    }
  }

  // ===== ESTADO DEL FORMULARIO =====
  
  String getWizardFormState() {
    if (isInPartialSaveMode && plagasRegistradasParcial.isNotEmpty) {
      return 'post_partial';
    }

    final hasPlaga = selectedPlaga != null && selectedPlaga!.isNotEmpty;
    final hasMuestras = muestra1Controller.text.isNotEmpty ||
        muestra2Controller.text.isNotEmpty ||
        muestra3Controller.text.isNotEmpty;
    final hasComentarios = comentariosController.text.isNotEmpty;
    final hasCantidadBotada = cantidadBotadaController.text.isNotEmpty &&
        cantidadBotadaController.text != '0';

    if (hasPlaga || hasMuestras || hasComentarios || hasCantidadBotada) {
      return 'dirty';
    }

    return 'clean';
  }

  // ===== NAVEGACIÓN DEL WIZARD =====
  
  Future<void> wizardNext() async {
    if (!_isWizardActive) return;
    
    final formState = getWizardFormState();

    // Si hay datos sin guardar, preguntar
    if (formState == 'dirty') {
      final confirmar = await _showWizardConfirmDialog(
        title: 'Datos sin guardar',
        message: '¿Desea guardar los datos antes de continuar?',
        confirmText: 'Guardar y continuar',
        cancelText: 'Descartar',
        showThirdOption: true,
        thirdOptionText: 'Cancelar',
      );

      if (confirmar == null) return;

      if (confirmar == true) {
        await saveMonitoreo();

        if (!lastSaveSuccess) {
          showMessage('Corrija los errores antes de continuar');
          return;
        }
      }
    }

    // Bloquear rango en primera navegación
    if (!_isWizardRangeLocked) {
      setState(() {
        _isWizardRangeLocked = true;
      });
    }

    final siguienteCantero = _wizardCanteroActual + 1;
    if (siguienteCantero <= _wizardCanteroFin) {
      _goToCantero(siguienteCantero);
    } else {
      wizardFinish();
    }
  }

  void wizardPrevious() {
    if (!_isWizardActive) return;
    if (_wizardCanteroActual > _wizardCanteroInicio) {
      _goToCantero(_wizardCanteroActual - 1);
    }
  }

  Future<void> wizardSkip() async {
    if (!_isWizardActive) return;
    
    final formState = getWizardFormState();
    String title = formState == 'dirty'
        ? 'Datos sin guardar'
        : formState == 'post_partial'
            ? 'Guardado parcial'
            : 'Saltar cantero';
    String message = formState == 'dirty'
        ? 'Tiene datos sin guardar. ¿Descartar y saltar?'
        : formState == 'post_partial'
            ? '¿Continuar sin agregar más plagas?'
            : '¿Saltar cantero $_wizardCanteroActual?';

    final confirmar = await _showWizardConfirmDialog(
      title: title,
      message: message,
      confirmText: 'Saltar',
      cancelText: 'Cancelar',
    );

    if (confirmar != true) return;

    if (!_isWizardRangeLocked) {
      setState(() {
        _isWizardRangeLocked = true;
      });
    }

    final siguienteCantero = _wizardCanteroActual + 1;
    if (siguienteCantero <= _wizardCanteroFin) {
      _goToCantero(siguienteCantero);
    } else {
      wizardFinish();
    }
  }

  void _goToCantero(int cantero) {
    if (cantero < _wizardCanteroInicio || cantero > _wizardCanteroFin) return;

    final secuencias = _wizardCanterosMonitoreos[cantero] ?? [];

    setState(() {
      _wizardCanteroActual = cantero;
      canteroController.text = cantero.toString();
      _wizardParcialIndex = 0;

      // Limpiar formulario
      selectedPlaga = null;
      comentariosController.clear();
      cantidadController.text = '0';
      cantidadBotadaController.clear();
      muestra1Controller.clear();
      muestra2Controller.clear();
      muestra3Controller.clear();
      selectedNivelMuestra1 = null;
      selectedNivelMuestra2 = null;
      selectedNivelMuestra3 = null;
      currentMonitoreo = null;
      isEditingExistingPartial = false;

      plagasRegistradasParcial.clear();
      variedadesUsadasParcial.clear();
    });

    if (secuencias.isNotEmpty) {
      _loadWizardCanteroMonitoreos(cantero, secuencias);
    } else {
      setState(() {
        _wizardFormState = 'clean';
        if (!_isWizardRangeLocked) {
          isInPartialSaveMode = false;
        }
      });
    }
  }

  // ===== CARGA DE MONITOREOS DEL CANTERO =====
  
  Future<void> _loadWizardCanteroMonitoreos(int cantero, List<int> secuencias) async {
    if (secuencias.isEmpty) return;

    final monitoreosCantero = monitoreoData
        .where((m) =>
            secuencias.contains(m.pmmo_secuencia) &&
            m.pmmo_cantero == cantero.toString())
        .toList();

    if (monitoreosCantero.isEmpty) {
      await loadData();
      return;
    }

    // Registrar plagas existentes
    for (var m in monitoreosCantero) {
      if (isManualEntry) {
        final clave = '${m.pmmo_cantero}|${m.pmmo_variedad}|${m.pmni_nombrecomun}';
        plagasRegistradasParcial.add(clave);
        if (m.pmmo_variedad != null) {
          variedadesUsadasParcial.add(m.pmmo_variedad!);
        }
      } else {
        if (m.pmni_nombrecomun != null) {
          plagasRegistradasParcial.add(m.pmni_nombrecomun!);
        }
      }
    }

    // Cargar primer monitoreo
    if (monitoreosCantero.isNotEmpty) {
      final primerMonitoreo = monitoreosCantero.first;
      await _editMonitoreoForWizard(primerMonitoreo);
      setState(() {
        _wizardFormState = 'post_partial';
        _wizardParcialIndex = 0;
      });
    }
  }

  Future<void> _editMonitoreoForWizard(Monitoreo monitoreo) async {
    setState(() {
      currentMonitoreo = monitoreo;
      isEditingExistingPartial = true;
      selectedPlaga = monitoreo.pmni_nombrecomun;
      comentariosController.text = monitoreo.pmmo_comentarios ?? '';
      cantidadController.text = monitoreo.pmmo_cantidad?.toString() ?? '0';
      cantidadBotadaController.text = monitoreo.pmmo_cant_botada?.toString() ?? '';
      muestra1Controller.text = monitoreo.pmmo_muestra1?.toString() ?? '';
      muestra2Controller.text = monitoreo.pmmo_muestra2?.toString() ?? '';
      muestra3Controller.text = monitoreo.pmmo_muestra3?.toString() ?? '';
      selectedNivelMuestra1 = monitoreo.pmmo_nivmuestram1?.toString();
      selectedNivelMuestra2 = monitoreo.pmmo_nivmuestram2?.toString();
      selectedNivelMuestra3 = monitoreo.pmmo_nivmuestram3?.toString();
    });
  }

  // ===== NAVEGACIÓN DE PARCIALES =====
  
  void wizardParcialPrevious() {
    final secuencias = _wizardCanterosMonitoreos[_wizardCanteroActual] ?? [];
    if (secuencias.isEmpty || _wizardParcialIndex <= 0) return;

    setState(() {
      _wizardParcialIndex--;
    });

    final secuencia = secuencias[_wizardParcialIndex];
    final monitoreo = monitoreoData.firstWhere(
      (m) => m.pmmo_secuencia == secuencia,
      orElse: () => monitoreoData.first,
    );
    _editMonitoreoForWizard(monitoreo);
  }

  void wizardParcialNext() {
    final secuencias = _wizardCanterosMonitoreos[_wizardCanteroActual] ?? [];
    if (secuencias.isEmpty) return;

    if (_wizardParcialIndex < secuencias.length - 1) {
      setState(() {
        _wizardParcialIndex++;
      });
      final secuencia = secuencias[_wizardParcialIndex];
      final monitoreo = monitoreoData.firstWhere(
        (m) => m.pmmo_secuencia == secuencia,
        orElse: () => monitoreoData.first,
      );
      _editMonitoreoForWizard(monitoreo);
    } else {
      // Ir a nuevo registro
      setState(() {
        _wizardParcialIndex = secuencias.length;
        currentMonitoreo = null;
        isEditingExistingPartial = false;
        selectedPlaga = null;
        comentariosController.clear();
        cantidadController.text = '0';
        cantidadBotadaController.clear();
        muestra1Controller.clear();
        muestra2Controller.clear();
        muestra3Controller.clear();
        selectedNivelMuestra1 = null;
        selectedNivelMuestra2 = null;
        selectedNivelMuestra3 = null;
      });
    }
  }

  bool canWizardParcialPrevious() {
    return _wizardParcialIndex > 0;
  }

  bool canWizardParcialNext() {
    final secuencias = _wizardCanterosMonitoreos[_wizardCanteroActual] ?? [];
    return secuencias.isNotEmpty || _wizardParcialIndex == 0;
  }

  String getWizardParcialInfo() {
    final secuencias = _wizardCanterosMonitoreos[_wizardCanteroActual] ?? [];
    if (secuencias.isEmpty) return 'Nuevo';
    
    final total = secuencias.length;
    final current = _wizardParcialIndex + 1;
    
    if (_wizardParcialIndex >= total) {
      return 'Nuevo ($total existentes)';
    }
    
    return 'Parcial $current de $total';
  }

  // ===== FINALIZACIÓN DEL WIZARD =====
  
  Future<void> wizardFinish() async {
    if (!_isWizardActive) return;
    
    final formState = getWizardFormState();

    if (formState == 'dirty') {
      final confirmar = await _showWizardConfirmDialog(
        title: 'Finalizar wizard',
        message: 'Tiene datos sin guardar. ¿Guardar antes de finalizar?',
        confirmText: 'Guardar y finalizar',
        cancelText: 'Descartar',
        showThirdOption: true,
        thirdOptionText: 'Cancelar',
      );

      if (confirmar == null) return;

      if (confirmar == true) {
        await saveMonitoreo();

        if (!lastSaveSuccess) {
          showMessage('Corrija los errores antes de finalizar');
          return;
        }
      }
    } else if (formState == 'post_partial') {
      final confirmar = await _showWizardConfirmDialog(
        title: 'Finalizar',
        message: '¿Finalizar wizard?',
        confirmText: 'Finalizar',
        cancelText: 'Continuar',
      );
      if (confirmar != true) return;
    }

    final canterosConDatos = _wizardCanterosMonitoreos.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => e.key)
        .toList();

    setState(() {
      _isWizardActive = false;
      _isWizardRangeLocked = false;
      _wizardCanteroActual = 0;
      _wizardCanteroInicio = 0;
      _wizardCanteroFin = 0;
      _wizardTotalCanteros = 0;
      _wizardFormState = 'clean';
      _wizardCanterosMonitoreos.clear();
      _wizardParcialIndex = 0;
      canterosRangeController.clear();
    });

    showMessage('Wizard finalizado. ${canterosConDatos.length} canteros con datos.');
  }

  // ===== DIÁLOGO DE CONFIRMACIÓN =====
  
  Future<bool?> _showWizardConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required String cancelText,
    bool showThirdOption = false,
    String? thirdOptionText,
  }) async {
    return showDialog<bool?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help_outline, color: Colors.indigo.shade600),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          if (showThirdOption && thirdOptionText != null)
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(thirdOptionText),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade600,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  // ===== VALIDADORES =====
  
  bool canWizardGoNext() =>
      _isWizardActive && (_wizardCanteroActual + 1) <= _wizardCanteroFin;

  bool canWizardGoPrevious() =>
      _isWizardActive && _wizardCanteroActual > _wizardCanteroInicio;

  void onCanterosRangeChanged(String range) {
    if (_isWizardRangeLocked) return;
    
    final parser = CanteroRangeParser.parse(range);
    if (parser.isValid) {
      setState(() {
        _wizardCanteroInicio = parser.inicio;
        _wizardCanteroFin = parser.fin;
        _wizardTotalCanteros = parser.total;
        _wizardCanteroActual = parser.inicio;
        _isWizardActive = !parser.isSingleCantero;
        canteroController.text = parser.inicio.toString();
      });
    }
  }

  // ===== REGISTRO DE GUARDADO PARCIAL DEL WIZARD =====
  
  void registerWizardPartialSave(int secuencia) {
    if (!_isWizardActive) return;
    
    setState(() {
      if (!_wizardCanterosMonitoreos.containsKey(_wizardCanteroActual)) {
        _wizardCanterosMonitoreos[_wizardCanteroActual] = [];
      }
      if (!_wizardCanterosMonitoreos[_wizardCanteroActual]!.contains(secuencia)) {
        _wizardCanterosMonitoreos[_wizardCanteroActual]!.add(secuencia);
      }
      _wizardFormState = 'post_partial';
      _lastCreatedSequence = secuencia;
    });
  }
}