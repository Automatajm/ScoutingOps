// lib/services/offline_database_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import '../data/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineDatabaseService extends ChangeNotifier {
  final AppDatabase _database;
  bool _isInitialized = false;

  OfflineDatabaseService(this._database);

  bool get isInitialized => _isInitialized;
  AppDatabase get database => _database;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final stats = await _database.getDatabaseStats();
      debugPrint('📦 Base de datos inicializada: $stats');
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error inicializando base de datos: $e');
      rethrow;
    }
  }

  // ========================================================================
  // MONITOREOS
  // ========================================================================

  Future<void> saveMonitoreoFromMap(Map<String, dynamic> data,
      {bool isLocal = false}) async {
    try {
      await _database.saveMonitoreoLocal(MonitoreosLocalCompanion(
        pmmoSecuencia: Value(data['pmmo_secuencia'] ?? 0),
        pmltCodigo: Value(data['pmlt_codigo']),
        pmmoCasa: Value(data['pmmo_casa']),
        pmmoCantero: Value(data['pmmo_cantero']),
        pmmoCanteros: Value(data['pmmo_canteros']),
        pmmoVariedad: Value(data['pmmo_variedad']),
        pmmoGrower: Value(data['pmmo_grower']),
        pmniNombrecomun: Value(data['pmni_nombrecomun']),
        pmmoCantidad: Value(data['pmmo_cantidad']),
        pmmoCantBotada: Value(data['pmmo_cant_botada']),
        pmmoComentarios: Value(data['pmmo_comentarios']),
        pmmoFecha: Value(data['pmmo_fecha'] != null
            ? DateTime.tryParse(data['pmmo_fecha'].toString())
            : null),
        pmmoAutomatico: Value(data['pmmo_automatico'] ?? true),
        pmmoEstatus: Value(data['pmmo_estatus'] ?? 1),
        pmmoCreadopor: Value(data['pmmo_creadopor']),
        pmmoContenedor: Value(data['pmmo_contenedor']),
        pmmoIdvariedad: Value(data['pmmo_idvariedad']),
        pmniId: Value(data['pmni_id']),
        pmmoMuestra1: Value(data['pmmo_muestra1']),
        pmmoMuestra2: Value(data['pmmo_muestra2']),
        pmmoMuestra3: Value(data['pmmo_muestra3']),
        pmmoNivmuestraa1: Value(data['pmmo_nivmuestraa1']),
        pmmoNivmuestraa2: Value(data['pmmo_nivmuestraa2']),
        pmmoNivmuestraa3: Value(data['pmmo_nivmuestraa3']),
        pmmoNivmuestram1: Value(data['pmmo_nivmuestram1']),
        pmmoNivmuestram2: Value(data['pmmo_nivmuestram2']),
        pmmoNivmuestram3: Value(data['pmmo_nivmuestram3']),
        lmsupniv1: Value(data['lmsupniv1']),
        lmsupniv2: Value(data['lmsupniv2']),
        lmsupniv3: Value(data['lmsupniv3']),
        isLocal: Value(isLocal),
        syncedAt: Value(isLocal ? null : DateTime.now()),
        version: const Value(1),
      ));
      debugPrint('💾 Monitoreo ${data['pmmo_secuencia']} guardado localmente');
    } catch (e) {
      debugPrint('❌ Error guardando monitoreo: $e');
      rethrow;
    }
  }

  Future<void> saveMonitoreosFromMaps(
      List<Map<String, dynamic>> monitoreos) async {
    for (final monitoreo in monitoreos) {
      await saveMonitoreoFromMap(monitoreo);
    }
    debugPrint('💾 ${monitoreos.length} monitoreos guardados localmente');
  }

  Future<Map<String, dynamic>?> getMonitoreoById(int id) async {
    final data = await _database.getMonitoreoById(id);
    if (data == null) return null;
    return _monitoreoDataToMap(data);
  }

  Future<List<Map<String, dynamic>>> getAllMonitoreos() async {
    final dataList = await _database.getAllMonitoreosLocales();
    return dataList.map(_monitoreoDataToMap).toList();
  }

  Future<List<Map<String, dynamic>>> getMonitoreosByUser(int userId) async {
    final dataList = await _database.getMonitoreosByUser(userId);
    return dataList.map(_monitoreoDataToMap).toList();
  }

  Future<List<Map<String, dynamic>>> getPendingMonitoreos() async {
    final dataList = await _database.getMonitoreosLocalOnly();
    return dataList.map(_monitoreoDataToMap).toList();
  }

  Future<void> deleteMonitoreo(int id) async {
    await _database.deleteMonitoreoLocal(id);
    debugPrint('🗑️ Monitoreo $id eliminado localmente');
  }

  Map<String, dynamic> _monitoreoDataToMap(MonitoreosLocalData data) {
    return {
      'pmmo_secuencia': data.pmmoSecuencia,
      'pmlt_codigo': data.pmltCodigo,
      'pmmo_casa': data.pmmoCasa,
      'pmmo_cantero': data.pmmoCantero,
      'pmmo_canteros': data.pmmoCanteros,
      'pmmo_variedad': data.pmmoVariedad,
      'pmmo_grower': data.pmmoGrower,
      'pmni_nombrecomun': data.pmniNombrecomun,
      'pmmo_cantidad': data.pmmoCantidad,
      'pmmo_cant_botada': data.pmmoCantBotada,
      'pmmo_comentarios': data.pmmoComentarios,
      'pmmo_fecha': data.pmmoFecha?.toIso8601String(),
      'pmmo_automatico': data.pmmoAutomatico,
      'pmmo_estatus': data.pmmoEstatus,
      'pmmo_creadopor': data.pmmoCreadopor,
      'pmmo_contenedor': data.pmmoContenedor,
      'pmmo_idvariedad': data.pmmoIdvariedad,
      'pmni_id': data.pmniId,
      'pmmo_muestra1': data.pmmoMuestra1,
      'pmmo_muestra2': data.pmmoMuestra2,
      'pmmo_muestra3': data.pmmoMuestra3,
      'pmmo_nivmuestraa1': data.pmmoNivmuestraa1,
      'pmmo_nivmuestraa2': data.pmmoNivmuestraa2,
      'pmmo_nivmuestraa3': data.pmmoNivmuestraa3,
      'pmmo_nivmuestram1': data.pmmoNivmuestram1,
      'pmmo_nivmuestram2': data.pmmoNivmuestram2,
      'pmmo_nivmuestram3': data.pmmoNivmuestram3,
      'lmsupniv1': data.lmsupniv1,
      'lmsupniv2': data.lmsupniv2,
      'lmsupniv3': data.lmsupniv3,
      'is_local': data.isLocal,
      'synced_at': data.syncedAt?.toIso8601String(),
      'version': data.version,
    };
  }

  // ========================================================================
  // CATÁLOGOS
  // ========================================================================

  Future<void> saveCatalogo(String tipo, dynamic data, {String? clave}) async {
    try {
      final jsonString = data is String ? data : jsonEncode(data);
      await _database.saveCatalogo(tipo, jsonString, clave: clave);
      debugPrint('💾 Catálogo "$tipo" guardado');
    } catch (e) {
      debugPrint('❌ Error guardando catálogo $tipo: $e');
      rethrow;
    }
  }

  Future<dynamic> getCatalogo(String tipo, {String? clave}) async {
    try {
      // getCatalogo ahora retorna Map<String, dynamic>? en lugar de CatalogosData?
      final catalogoMap = await _database.getCatalogo(tipo, clave: clave);
      if (catalogoMap == null) return null;

      // El campo 'data' contiene el JSON string
      final dataString = catalogoMap['data'] as String?;
      if (dataString == null) return null;

      return jsonDecode(dataString);
    } catch (e) {
      debugPrint('❌ Error obteniendo catálogo $tipo: $e');
      return null;
    }
  }

  Future<void> saveVariedades(List<dynamic> variedades) async {
    await saveCatalogo('variedades', variedades);
  }

  Future<List<dynamic>?> getVariedades() async {
    final data = await getCatalogo('variedades');
    return data is List ? data : null;
  }

  Future<void> saveCasas(List<dynamic> casas) async {
    await saveCatalogo('casas', casas);
  }

  Future<List<dynamic>?> getCasas() async {
    final data = await getCatalogo('casas');
    return data is List ? data : null;
  }

  Future<void> savePlagas(List<String> plagas) async {
    await saveCatalogo('plagas_nombres', plagas);
  }

  Future<List<String>?> getPlagas() async {
    final data = await getCatalogo('plagas_nombres');
    if (data is List) {
      return data.cast<String>();
    }
    return null;
  }

  Future<void> saveNivelesLimites(Map<String, dynamic> niveles) async {
    await saveCatalogo('niveles_limites', niveles);
  }

  Future<Map<String, dynamic>?> getNivelesLimites() async {
    final data = await getCatalogo('niveles_limites');
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  Future<void> saveLoteInfo(
      String codigo, Map<String, dynamic> loteInfo) async {
    await saveCatalogo('lote_info', loteInfo, clave: codigo);
  }

  Future<Map<String, dynamic>?> getLoteInfo(String codigo) async {
    final data = await getCatalogo('lote_info', clave: codigo);
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  // ========================================================================
  // SYNC METADATA
  // ========================================================================

  Future<void> saveMetadata(String key, String value) async {
    await _database.saveSyncMetadata(key, value);
  }

  Future<String?> getMetadata(String key) async {
    return await _database.getSyncMetadata(key);
  }

  Future<DateTime?> getLastSyncTime() async {
    return await _database.getLastSyncTime();
  }

  Future<void> saveLastSyncTime() async {
    await _database.saveLastSyncTime();
  }

  // ============================================================
  // MÉTODOS DE METADATA PARA SYNC
  // ============================================================

  /// Guarda metadata de sincronización
  Future<void> saveSyncMetadata(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_meta_$key', value);
  }

  /// Obtiene metadata de sincronización
  Future<String?> getSyncMetadata(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sync_meta_$key');
  }

  // ========================================================================
  // UTILIDADES
  // ========================================================================

  Future<bool> hasLocalData() async {
    final stats = await _database.getDatabaseStats();
    return (stats['monitoreos_locales'] ?? 0) > 0;
  }

  Future<Map<String, dynamic>> getStorageStats() async {
    final dbStats = await _database.getDatabaseStats();
    final lastSync = await getLastSyncTime();

    return {
      'monitoreos_count': dbStats['monitoreos_locales'],
      'pending_operations': dbStats['pending_operations'],
      'catalogos_count': dbStats['catalogos'],
      'last_sync': lastSync?.toIso8601String(),
      'is_initialized': _isInitialized,
    };
  }

  Future<void> clearAllData() async {
    await _database.clearAllData();
    debugPrint('🗑️ Todos los datos locales eliminados');
    notifyListeners();
  }

  Future<void> clearMonitoreos() async {
    await _database.clearAllMonitoreosLocales();
    debugPrint('🗑️ Monitoreos locales eliminados');
    notifyListeners();
  }

  Future<void> clearCatalogos() async {
    await _database.clearAllCatalogos();
    debugPrint('🗑️ Catálogos eliminados');
    notifyListeners();
  }
}
