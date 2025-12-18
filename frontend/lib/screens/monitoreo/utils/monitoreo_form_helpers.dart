import 'package:flutter/material.dart';
import '../../../models/monitoreo_model.dart';

/// Clase de utilidades estáticas para el formulario de monitoreo
class MonitoreoFormHelpers {
  MonitoreoFormHelpers._(); // Constructor privado para prevenir instanciación

  // ===== CÓDIGO POR DEFECTO =====
  
  static String getDefaultLoteCode() => "15207";

  // ===== MANEJO DE VARIEDAD =====
  
  static String obtenerIdVariedad(
    String? descripcionVariedad,
    Map<String, String> variedadesIdMap,
  ) {
    if (descripcionVariedad == null) return '';
    if (descripcionVariedad == 'Variedad genérica') return '0';
    return variedadesIdMap[descripcionVariedad] ?? '';
  }

  static void updateResponsable(
    String? variedad,
    Map<String, String> responsablesPorVariedad,
    TextEditingController responsableController,
  ) {
    if (variedad == null) return;
    
    if (variedad == 'Variedad genérica') {
      responsableController.clear();
    } else if (responsablesPorVariedad.containsKey(variedad)) {
      responsableController.text = responsablesPorVariedad[variedad] ?? '';
    } else {
      responsableController.text = '';
    }
  }

  // ===== VALIDACIÓN DE PLAGAS =====
  
  static bool isPlagaAlreadyRegistered(
    String? plaga,
    String? variedad,
    String cantero,
    Set<String> plagasRegistradas,
    bool isManualEntry,
  ) {
    if (plaga == null) return false;
    
    if (isManualEntry) {
      final clave = '$cantero|$variedad|$plaga';
      return plagasRegistradas.contains(clave);
    } else {
      return plagasRegistradas.contains(plaga);
    }
  }

  // ===== REGISTRO DE PLAGAS PARCIALES =====
  
  static void registerPlagaParcial(
    String? plaga,
    String? variedad,
    String cantero,
    Set<String> plagasRegistradas,
    Set<String> variedadesUsadas,
    bool isManualEntry,
  ) {
    if (plaga == null) return;
    
    if (isManualEntry) {
      final clave = '$cantero|$variedad|$plaga';
      plagasRegistradas.add(clave);
      if (variedad != null) {
        variedadesUsadas.add(variedad);
      }
    } else {
      plagasRegistradas.add(plaga);
    }
  }

  // ===== LIMPIEZA DE FORMULARIO =====
  
  static void clearForm({
    required TextEditingController codigoLoteController,
    required TextEditingController casaController,
    required TextEditingController canteroController,
    required TextEditingController responsableController,
    required TextEditingController comentariosController,
    required TextEditingController cantidadController,
    required TextEditingController cantidadBotadaController,
    required TextEditingController muestra1Controller,
    required TextEditingController muestra2Controller,
    required TextEditingController muestra3Controller,
    required TextEditingController canterosRangeController,
    required Function(void Function()) setState,
    required Map<String, dynamic> formState,
  }) {
    codigoLoteController.clear();
    casaController.clear();
    canteroController.clear();
    responsableController.clear();
    comentariosController.clear();
    cantidadController.clear();
    cantidadBotadaController.clear();
    muestra1Controller.clear();
    muestra2Controller.clear();
    muestra3Controller.clear();
    canterosRangeController.clear();

    setState(() {
      formState['selectedVariedad'] = null;
      formState['selectedPlaga'] = null;
      formState['selectedCasa'] = null;
      formState['selectedNivelMuestra1'] = null;
      formState['selectedNivelMuestra2'] = null;
      formState['selectedNivelMuestra3'] = null;
      formState['currentMonitoreo'] = null;
      formState['isEditing'] = false;
      formState['isCreatingNew'] = false;
      formState['isManualEntry'] = false;
      formState['errorMessage'] = '';
      formState['loteCanterosOriginal'] = null;
      formState['loteContenedorOriginal'] = null;
      formState['cantidadController'] = '0';
    });
  }

  static void clearMonitoreoData({
    required TextEditingController comentariosController,
    required TextEditingController cantidadController,
    required TextEditingController cantidadBotadaController,
    required TextEditingController muestra1Controller,
    required TextEditingController muestra2Controller,
    required TextEditingController muestra3Controller,
    required bool isInPartialSaveMode,
  }) {
    comentariosController.clear();
    cantidadController.clear();
    cantidadBotadaController.clear();
    
    if (!isInPartialSaveMode) {
      muestra1Controller.clear();
      muestra2Controller.clear();
      muestra3Controller.clear();
    }
  }

  // ===== CÁLCULO DE CANTIDADES =====
  
  static int calcularCantidadTotal(
    TextEditingController muestra1Controller,
    TextEditingController muestra2Controller,
    TextEditingController muestra3Controller,
  ) {
    int muestra1 = int.tryParse(muestra1Controller.text) ?? 0;
    int muestra2 = int.tryParse(muestra2Controller.text) ?? 0;
    int muestra3 = int.tryParse(muestra3Controller.text) ?? 0;
    return muestra1 + muestra2 + muestra3;
  }

  static void actualizarCantidadObservada({
    required TextEditingController muestra1Controller,
    required TextEditingController muestra2Controller,
    required TextEditingController muestra3Controller,
    required TextEditingController cantidadController,
    required Function(void Function()) setState,
  }) {
    setState(() {
      cantidadController.text = calcularCantidadTotal(
        muestra1Controller,
        muestra2Controller,
        muestra3Controller,
      ).toString();
    });
  }

  // ===== OBTENCIÓN DE LISTAS =====
  
  static List<String> obtenerListaCanteros(List<Monitoreo> monitoreoData) {
    Set<String> canteros = {'Todos'};
    
    for (var monitoreo in monitoreoData) {
      if (monitoreo.pmmo_cantero != null &&
          monitoreo.pmmo_cantero!.isNotEmpty &&
          monitoreo.pmmo_cantero != 'Todos') {
        canteros.add(monitoreo.pmmo_cantero!);
      }
    }
    
    List<String> resultado = canteros.toList();
    resultado.sort((a, b) => a == 'Todos'
        ? -1
        : b == 'Todos'
            ? 1
            : a.compareTo(b));
    
    return resultado;
  }

  // ===== VALIDACIÓN DE MONITOREOS TEMPORALES =====
  
  static bool isTemporaryMonitoreo(Monitoreo monitoreo) {
    return (monitoreo.pmmo_secuencia != null && monitoreo.pmmo_secuencia! < 0) ||
        (monitoreo.isOfflineCreated == true);
  }

  // ===== FORMATEO DE FECHAS =====
  
  static String formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // ===== VALIDACIÓN DE FORMULARIO =====
  
  static String? validateForm({
    required bool isManualEntry,
    required String? selectedVariedad,
    required String codigoLote,
    required String? selectedCasa,
    required String cantero,
    required String? selectedPlaga,
    required String cantidad,
  }) {
    if (isManualEntry && (selectedVariedad == null || selectedVariedad.isEmpty)) {
      return 'Seleccione variedad';
    }
    
    if (codigoLote.isEmpty) {
      return 'Ingrese código de lote';
    }
    
    if (selectedCasa == null || selectedCasa.isEmpty) {
      return 'Seleccione casa';
    }
    
    if (cantero.isEmpty) {
      return 'Ingrese cantero';
    }
    
    if (selectedPlaga == null || selectedPlaga.isEmpty) {
      return 'Seleccione plaga';
    }
    
    if (cantidad.isEmpty) {
      return 'Ingrese cantidad';
    }
    
    return null; // Sin errores
  }

  // ===== CREACIÓN DE MONITOREO =====
  
  static Monitoreo createMonitoreoFromForm({
    required int? currentSequence,
    required String codigoLote,
    required String casa,
    required String cantero,
    required String canterosRange,
    required String? variedad,
    required String idVariedad,
    required String responsable,
    required String plaga,
    required int cantidad,
    required int cantidadBotada,
    required String comentarios,
    required bool isManualEntry,
    required int? userId,
    required int? nivelMuestra1,
    required int? nivelMuestra2,
    required int? nivelMuestra3,
    required int muestra1,
    required int muestra2,
    required int muestra3,
    required int? limiteNivel1,
    required int? limiteNivel2,
    required int? limiteNivel3,
    required String? contenedor,
  }) {
    return Monitoreo(
      pmmo_secuencia: currentSequence,
      pmlt_codigo: codigoLote,
      pmmo_casa: casa,
      pmmo_cantero: cantero,
      pmmo_canteros: canterosRange.isNotEmpty ? canterosRange : cantero,
      pmmo_variedad: variedad ?? '',
      pmmo_idvariedad: idVariedad,
      pmmo_grower: responsable,
      pmni_nombrecomun: plaga,
      pmmo_cantidad: cantidad,
      pmmo_cant_botada: cantidadBotada,
      pmmo_comentarios: comentarios,
      pmmo_fecha: DateTime.now(),
      pmmo_automatico: !isManualEntry,
      pmmo_estatus: 1,
      pmmo_creadopor: userId,
      pmmo_fechacreacion: DateTime.now(),
      pmmo_nivmuestram1: nivelMuestra1,
      pmmo_nivmuestram2: nivelMuestra2,
      pmmo_nivmuestram3: nivelMuestra3,
      pmmo_muestra1: muestra1,
      pmmo_muestra2: muestra2,
      pmmo_muestra3: muestra3,
      lmsupniv1: limiteNivel1,
      lmsupniv2: limiteNivel2,
      lmsupniv3: limiteNivel3,
      pmmo_contenedor: contenedor,
    );
  }
}