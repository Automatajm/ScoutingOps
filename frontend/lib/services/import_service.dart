// 📁 UBICACIÓN: lib/services/import_service.dart
// ⚡ ARCHIVO NUEVO - Crear este archivo

import 'package:flutter/foundation.dart';
import '../models/lote_model.dart';
import '../models/import_analysis_model.dart';
import '../services/lote_service.dart';

class ImportService {
  final LoteService _loteService = LoteService();

  /// Analiza los lotes del Excel y los compara con los existentes
  Future<ImportAnalysis> analizarImportacion(List<Lote> lotesExcel) async {
    debugPrint("🔍 === INICIANDO ANÁLISIS DE IMPORTACIÓN ===");
    debugPrint("📊 Lotes en Excel: ${lotesExcel.length}");

    // Obtener todos los lotes existentes
    final lotesExistentes = await _loteService.getLotes();
    debugPrint("📦 Lotes existentes en BD: ${lotesExistentes.length}");

    // Crear mapa de lotes existentes por código (case-insensitive)
    final Map<String, Lote> mapaExistentes = {};
    for (var lote in lotesExistentes) {
      if (lote.pmlt_codigo != null && lote.pmlt_codigo!.isNotEmpty) {
        mapaExistentes[lote.pmlt_codigo!.toLowerCase()] = lote;
      }
    }

    List<LoteToCreate> lotesNuevos = [];
    List<LoteToUpdate> lotesActualizar = [];
    List<Lote> lotesSinCambios = [];

    // Analizar cada lote del Excel
    for (var loteExcel in lotesExcel) {
      final codigo = loteExcel.pmlt_codigo?.toLowerCase();

      if (codigo == null || codigo.isEmpty) {
        debugPrint("⚠️ Lote sin código, saltando...");
        continue;
      }

      if (mapaExistentes.containsKey(codigo)) {
        // Lote existe - verificar si tiene cambios
        final loteExistente = mapaExistentes[codigo]!;
        final cambios = _detectarCambios(loteExistente, loteExcel);

        if (cambios.isNotEmpty) {
          debugPrint(
              "🔄 Lote ${loteExcel.pmlt_codigo}: ${cambios.length} cambios detectados");
          lotesActualizar.add(LoteToUpdate(
            loteExistente: loteExistente,
            loteNuevo: loteExcel,
            cambios: cambios,
          ));
        } else {
          debugPrint("✓ Lote ${loteExcel.pmlt_codigo}: Sin cambios");
          lotesSinCambios.add(loteExistente);
        }
      } else {
        // Lote nuevo
        debugPrint("✨ Lote ${loteExcel.pmlt_codigo}: Nuevo");
        lotesNuevos.add(LoteToCreate(lote: loteExcel));
      }
    }

    debugPrint("📊 Resumen del análisis:");
    debugPrint("   ✨ Nuevos: ${lotesNuevos.length}");
    debugPrint("   🔄 Actualizar: ${lotesActualizar.length}");
    debugPrint("   ✓ Sin cambios: ${lotesSinCambios.length}");

    return ImportAnalysis(
      lotesNuevos: lotesNuevos,
      lotesActualizar: lotesActualizar,
      lotesSinCambios: lotesSinCambios,
    );
  }

  /// Detecta cambios entre un lote existente y uno del Excel
  List<FieldChange> _detectarCambios(Lote existente, Lote nuevo) {
    List<FieldChange> cambios = [];

    // Comparar Canteros
    if (_valorCambio(existente.pmlt_canteros, nuevo.pmlt_canteros)) {
      cambios.add(FieldChange(
        fieldName: 'pmlt_canteros',
        fieldLabel: 'Canteros',
        oldValue: existente.pmlt_canteros ?? '-',
        newValue: nuevo.pmlt_canteros ?? '-',
      ));
    }

    // Comparar Cantidad
    if (existente.pmlt_cantidad != nuevo.pmlt_cantidad) {
      cambios.add(FieldChange(
        fieldName: 'pmlt_cantidad',
        fieldLabel: 'Cantidad',
        oldValue: existente.pmlt_cantidad?.toString() ?? '0',
        newValue: nuevo.pmlt_cantidad?.toString() ?? '0',
      ));
    }

    // Comparar Contenedor
    if (_valorCambio(existente.pmlt_contenedor, nuevo.pmlt_contenedor)) {
      cambios.add(FieldChange(
        fieldName: 'pmlt_contenedor',
        fieldLabel: 'Contenedor',
        oldValue: existente.pmlt_contenedor ?? '-',
        newValue: nuevo.pmlt_contenedor ?? '-',
      ));
    }

    // Comparar Casa
    if (_valorCambio(existente.pmlt_casa, nuevo.pmlt_casa)) {
      cambios.add(FieldChange(
        fieldName: 'pmlt_casa',
        fieldLabel: 'Casa',
        oldValue: existente.pmlt_casa ?? '-',
        newValue: nuevo.pmlt_casa ?? '-',
      ));
    }

    // Comparar Grower
    if (_valorCambio(existente.pmlt_grower, nuevo.pmlt_grower)) {
      cambios.add(FieldChange(
        fieldName: 'pmlt_grower',
        fieldLabel: 'Grower',
        oldValue: existente.pmlt_grower ?? '-',
        newValue: nuevo.pmlt_grower ?? '-',
      ));
    }

    // Comparar Variedad
    if (_valorCambio(existente.pmlt_variedad, nuevo.pmlt_variedad)) {
      cambios.add(FieldChange(
        fieldName: 'pmlt_variedad',
        fieldLabel: 'Variedad',
        oldValue: existente.pmlt_variedad ?? '-',
        newValue: nuevo.pmlt_variedad ?? '-',
      ));
    }

    // Comparar ID Variedad
    if (existente.pmlt_idvariedad != nuevo.pmlt_idvariedad) {
      cambios.add(FieldChange(
        fieldName: 'pmlt_idvariedad',
        fieldLabel: 'ID Variedad',
        oldValue: existente.pmlt_idvariedad?.toString() ?? '-',
        newValue: nuevo.pmlt_idvariedad?.toString() ?? '-',
      ));
    }

    // Comparar Estatus
    if (existente.pmlt_estatus != nuevo.pmlt_estatus) {
      final estatusMap = {1: 'Activo', 0: 'Inactivo'};
      cambios.add(FieldChange(
        fieldName: 'pmlt_estatus',
        fieldLabel: 'Estado',
        oldValue: estatusMap[existente.pmlt_estatus] ?? '-',
        newValue: estatusMap[nuevo.pmlt_estatus] ?? '-',
      ));
    }

    return cambios;
  }

  /// Verifica si un valor de texto cambió (considerando null y vacío como equivalentes)
  bool _valorCambio(String? valorViejo, String? valorNuevo) {
    final viejo = (valorViejo ?? '').trim();
    final nuevo = (valorNuevo ?? '').trim();
    return viejo != nuevo;
  }

  /// Ejecuta la importación con las opciones seleccionadas
  /// VERSIÓN OPTIMIZADA: Usa endpoints masivos para mejor performance
  Future<ImportExecutionResult> ejecutarImportacion({
    required List<LoteToCreate> lotesCrear,
    required List<LoteToUpdate> lotesActualizar,
  }) async {
    debugPrint("🚀 === EJECUTANDO IMPORTACIÓN (MODO MASIVO) ===");
    debugPrint("✨ Lotes a crear: ${lotesCrear.length}");
    debugPrint("🔄 Lotes a actualizar: ${lotesActualizar.length}");

    int creados = 0;
    int actualizados = 0;
    int errores = 0;
    List<String> mensajesError = [];

    // ========== CREACIÓN MASIVA (si hay lotes nuevos) ==========
    if (lotesCrear.isNotEmpty) {
      try {
        debugPrint("📦 Creando ${lotesCrear.length} lotes nuevos en batch...");

        final lotesNuevos = lotesCrear.map((lc) => lc.lote).toList();
        final resultado = await _loteService.importarLotes(lotesNuevos);

        creados = resultado.creados;
        debugPrint("✅ Creados en batch: $creados lotes");
      } catch (e) {
        errores += lotesCrear.length;
        final mensaje = "Error en creación masiva: $e";
        mensajesError.add(mensaje);
        debugPrint("❌ $mensaje");
      }
    }

    // ========== ACTUALIZACIÓN MASIVA (si hay lotes a actualizar) ==========
    if (lotesActualizar.isNotEmpty) {
      try {
        debugPrint(
            "🔄 Actualizando ${lotesActualizar.length} lotes en batch...");

        // Construir lista de lotes actualizados
        final lotesParaActualizar = lotesActualizar.map((lu) {
          return lu.loteExistente.copyWith(
            pmlt_canteros: lu.loteNuevo.pmlt_canteros,
            pmlt_cantidad: lu.loteNuevo.pmlt_cantidad,
            pmlt_contenedor: lu.loteNuevo.pmlt_contenedor,
            pmlt_casa: lu.loteNuevo.pmlt_casa,
            pmlt_grower: lu.loteNuevo.pmlt_grower,
            pmlt_variedad: lu.loteNuevo.pmlt_variedad,
            pmlt_idvariedad: lu.loteNuevo.pmlt_idvariedad,
            pmlt_estatus: lu.loteNuevo.pmlt_estatus,
            pmlt_modificadopor: 1,
            pmlt_fechamodificacion: DateTime.now(),
          );
        }).toList();

        final resultado =
            await _loteService.actualizarLotesMasivo(lotesParaActualizar);

        // El campo 'creados' en ImportResult contiene la cantidad de actualizados
        actualizados = resultado.creados;
        debugPrint("✅ Actualizados en batch: $actualizados lotes");
      } catch (e) {
        errores += lotesActualizar.length;
        final mensaje = "Error en actualización masiva: $e";
        mensajesError.add(mensaje);
        debugPrint("❌ $mensaje");
      }
    }

    debugPrint("📊 Resultado final:");
    debugPrint("   ✅ Creados: $creados");
    debugPrint("   ✅ Actualizados: $actualizados");
    debugPrint("   ❌ Errores: $errores");

    return ImportExecutionResult(
      creados: creados,
      actualizados: actualizados,
      errores: errores,
      mensajesError: mensajesError,
    );
  }
}
