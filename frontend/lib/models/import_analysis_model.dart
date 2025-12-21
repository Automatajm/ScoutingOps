// 📁 UBICACIÓN: lib/models/import_analysis_model.dart
// ⚡ ARCHIVO NUEVO - Crear este archivo

// ⚠️ CRÍTICO: AGREGAR ESTE IMPORT
import 'lote_model.dart'; // ← ¡ESTO FALTABA!

// Modelo para representar el análisis de importación
class ImportAnalysis {
  final List<LoteToCreate> lotesNuevos;
  final List<LoteToUpdate> lotesActualizar;
  final List<Lote> lotesSinCambios;

  ImportAnalysis({
    required this.lotesNuevos,
    required this.lotesActualizar,
    required this.lotesSinCambios,
  });

  int get totalNuevos => lotesNuevos.length;
  int get totalActualizar => lotesActualizar.length;
  int get totalSinCambios => lotesSinCambios.length;
  int get totalLotes => totalNuevos + totalActualizar + totalSinCambios;
}

// Lote nuevo a crear
class LoteToCreate {
  final Lote lote;

  LoteToCreate({required this.lote});
}

// Lote existente a actualizar con detalle de cambios
class LoteToUpdate {
  final Lote loteExistente;
  final Lote loteNuevo;
  final List<FieldChange> cambios;

  LoteToUpdate({
    required this.loteExistente,
    required this.loteNuevo,
    required this.cambios,
  });

  bool get tieneCambios => cambios.isNotEmpty;
}

// Cambio en un campo específico
class FieldChange {
  final String fieldName;
  final String fieldLabel;
  final String? oldValue;
  final String? newValue;

  FieldChange({
    required this.fieldName,
    required this.fieldLabel,
    required this.oldValue,
    required this.newValue,
  });

  @override
  String toString() {
    return '$fieldLabel: "$oldValue" → "$newValue"';
  }
}

// Resultado de la importación ejecutada
class ImportExecutionResult {
  final int creados;
  final int actualizados;
  final int errores;
  final List<String> mensajesError;

  ImportExecutionResult({
    required this.creados,
    required this.actualizados,
    this.errores = 0,
    this.mensajesError = const [],
  });

  bool get exitoso => errores == 0;
  int get totalProcesados => creados + actualizados;
}
