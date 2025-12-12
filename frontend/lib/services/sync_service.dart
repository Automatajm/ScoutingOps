// lib/services/sync_service.dart
// ============================================================
// SERVICIO DE SINCRONIZACIÓN BIDIRECCIONAL
// Compatible con OfflineDatabaseService
// ============================================================
// INSTRUCCIONES:
// 1. Crear el archivo en lib/services/sync_service.dart
// 2. Importar donde se necesite
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/offline_database_service.dart';

/// Estado de sincronización
enum SyncStatus {
  idle,
  syncing,
  success,
  error,
  offline,
}

/// Estado combinado para el UI
class SyncState {
  final bool isSyncing;
  final int pendingCount;
  final String? lastError;
  final DateTime? lastSyncTime;
  final SyncStatus status;

  SyncState({
    required this.isSyncing,
    required this.pendingCount,
    this.lastError,
    this.lastSyncTime,
    this.status = SyncStatus.idle,
  });
}

/// Resultado de sync
class SyncResult {
  final bool success;
  final String message;
  final int pushed;
  final int pulled;
  final int conflicts;
  final int failed;
  final int cleaned;
  final DateTime? serverTime;
  final String? error;

  // Alias para compatibilidad
  int get uploaded => pushed;
  int get downloaded => pulled;

  SyncResult({
    required this.success,
    required this.message,
    this.pushed = 0,
    this.pulled = 0,
    this.conflicts = 0,
    this.failed = 0,
    this.cleaned = 0,
    this.serverTime,
    this.error,
  });

  factory SyncResult.error(String message) => SyncResult(
        success: false,
        message: message,
        error: message,
      );

  factory SyncResult.offline() => SyncResult(
        success: false,
        message: 'Sin conexión a internet',
        error: 'Sin conexión a internet',
      );
}

/// Servicio principal de sincronización
class SyncService {
  final OfflineDatabaseService _db;
  final String _baseUrl;
  final int _userId;
  final int _windowDays; // Ventana de días a sincronizar (default 2)

  // Estado observable individual
  final ValueNotifier<SyncStatus> status = ValueNotifier(SyncStatus.idle);
  final ValueNotifier<int> pendingCount = ValueNotifier(0);
  final ValueNotifier<String?> lastError = ValueNotifier(null);
  final ValueNotifier<DateTime?> lastSyncTime = ValueNotifier(null);

  // Estado combinado para el UI
  final ValueNotifier<SyncState> syncState = ValueNotifier(SyncState(
    isSyncing: false,
    pendingCount: 0,
  ));

  // Control interno
  Timer? _autoSyncTimer;
  bool _isSyncing = false;
  Completer<void>? _syncCompleter;

  SyncService({
    required OfflineDatabaseService database,
    required String baseUrl,
    required int userId,
    int windowDays = 2, // Solo sincroniza 2 días
  })  : _db = database,
        _baseUrl = baseUrl,
        _userId = userId,
        _windowDays = windowDays {
    _init();
  }

  void _updateSyncState() {
    syncState.value = SyncState(
      isSyncing: _isSyncing,
      pendingCount: pendingCount.value,
      lastError: lastError.value,
      lastSyncTime: lastSyncTime.value,
      status: status.value,
    );
  }

  Future<void> _init() async {
    await _updatePendingCount();
    // OfflineDatabaseService no tiene getLastSyncTime, usar metadata
    final lastSyncStr = await _db.getSyncMetadata('last_sync_monitoreos');
    if (lastSyncStr != null && lastSyncStr.isNotEmpty) {
      lastSyncTime.value = DateTime.tryParse(lastSyncStr);
    }
    _updateSyncState();
  }

  Future<void> _updatePendingCount() async {
    // Contar monitoreos pendientes de sincronizar
    final allMonitoreos = await _db.getAllMonitoreos();
    final pending = allMonitoreos.where((m) {
      // Pendientes son los que tienen ID temporal (negativo) o flag isLocal
      final id = m['pmmo_secuencia'] as int?;
      final isLocal = m['is_local'] as bool? ?? false;
      final needsSync = m['needs_sync'] as bool? ?? false;
      return (id != null && id < 0) || isLocal || needsSync;
    }).length;
    pendingCount.value = pending;
    _updateSyncState();
  }

  /// Inicia sync automático periódico
  void startAutoSync({Duration interval = const Duration(minutes: 5)}) {
    stopAutoSync();
    _autoSyncTimer = Timer.periodic(interval, (_) => syncFull());
    debugPrint('🔄 Auto-sync iniciado: cada ${interval.inMinutes} minutos');
  }

  /// Detiene sync automático
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// Sincronización completa (push + pull) - SOLO 2 DÍAS
  Future<SyncResult> syncFull({bool force = false}) async {
    if (_isSyncing && !force) {
      debugPrint('⏳ Sync ya en progreso...');
      await _syncCompleter?.future;
      return SyncResult(success: true, message: 'Sync previo completado');
    }

    _isSyncing = true;
    _syncCompleter = Completer<void>();
    status.value = SyncStatus.syncing;
    lastError.value = null;
    _updateSyncState();

    try {
      debugPrint('🚀 Iniciando sincronización (ventana: $_windowDays días)...');

      // 1. Obtener pendientes desde OfflineDatabaseService
      final allMonitoreos = await _db.getAllMonitoreos();
      final pendientes = allMonitoreos.where((m) {
        final id = m['pmmo_secuencia'] as int?;
        final isLocal = m['is_local'] as bool? ?? false;
        final needsSync = m['needs_sync'] as bool? ?? false;
        final creadoPor = m['pmmo_creadopor'] as int?;
        return ((id != null && id < 0) || isLocal || needsSync) &&
            creadoPor == _userId;
      }).toList();
      debugPrint('📤 Pendientes de subir: ${pendientes.length}');

      // 2. Obtener último timestamp
      final lastSyncStr = await _db.getSyncMetadata('last_sync_monitoreos');
      final lastSync = lastSyncStr != null && lastSyncStr.isNotEmpty
          ? DateTime.tryParse(lastSyncStr)
          : null;
      debugPrint('⏰ Última sync: ${lastSync?.toIso8601String() ?? "nunca"}');

      // 3. Preparar payload
      final payload = {
        'usuario_id': _userId,
        'dias': _windowDays,
        'last_sync_timestamp': lastSync?.toIso8601String(),
        'monitoreos_pendientes':
            pendientes.map((m) => _prepareForUpload(m)).toList(),
      };

      // 4. Llamar endpoint
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/monitoreo/sync/full'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () =>
                throw TimeoutException('Timeout en sincronización'),
          );

      if (response.statusCode != 200) {
        throw Exception('Error del servidor: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);

      if (data['success'] != true) {
        throw Exception(data['message'] ?? 'Error desconocido');
      }

      // 5. Procesar PUSH
      final pushResults = data['push']['results'] as List? ?? [];
      final pushSummary =
          data['push']['summary'] as Map<String, dynamic>? ?? {};
      int conflictsCount = 0;

      for (final result in pushResults) {
        if (result['success'] == true) {
          final tempId = result['temp_id'] as int?;
          final serverId = result['server_id'] as int;

          if (tempId != null && tempId < 0) {
            // Eliminar el temporal y crear con ID real
            await _db.deleteMonitoreo(tempId);
            debugPrint('✅ Temporal $tempId → Server $serverId');
          }
        } else if (result['conflict'] == true) {
          conflictsCount++;
          debugPrint('⚠️ Conflicto: ${result['message']}');
        } else {
          debugPrint('❌ Error: ${result['message']}');
        }
      }

      // 6. Procesar PULL
      final pullData = data['pull']['data'] as List? ?? [];
      debugPrint('📥 Recibidos del servidor: ${pullData.length}');

      if (pullData.isNotEmpty) {
        for (final serverRecord in pullData) {
          await _db.saveMonitoreoFromMap(
            Map<String, dynamic>.from(serverRecord),
            isLocal: false,
          );
        }
      }

      // 7. Guardar timestamp
      final serverTime = data['meta']?['serverTime'] as String?;
      if (serverTime != null) {
        await _db.saveSyncMetadata('last_sync_monitoreos', serverTime);
        lastSyncTime.value = DateTime.parse(serverTime);
      }

      // 8. LIMPIAR REGISTROS ANTIGUOS (>2 días, ya sincronizados)
      final cleaned = await _cleanOldRecords();

      // 9. Actualizar estado
      await _updatePendingCount();
      status.value = SyncStatus.success;
      _updateSyncState();

      final result = SyncResult(
        success: true,
        message: 'Sincronización completada',
        pushed: (pushSummary['created'] ?? 0) + (pushSummary['updated'] ?? 0),
        pulled: pullData.length,
        conflicts: pushSummary['conflicts'] ?? conflictsCount,
        failed: pushSummary['failed'] ?? 0,
        cleaned: cleaned,
        serverTime: serverTime != null ? DateTime.parse(serverTime) : null,
      );

      debugPrint(
          '✅ Sync completado: ${result.pushed} subidos, ${result.pulled} descargados, ${result.cleaned} limpiados');

      return result;
    } on TimeoutException {
      status.value = SyncStatus.error;
      lastError.value = 'Timeout en sincronización';
      _updateSyncState();
      return SyncResult.error('Timeout: el servidor no respondió');
    } on http.ClientException catch (e) {
      status.value = SyncStatus.offline;
      lastError.value = 'Sin conexión';
      _updateSyncState();
      return SyncResult.error('Error de conexión: ${e.message}');
    } catch (e) {
      status.value = SyncStatus.error;
      lastError.value = e.toString();
      _updateSyncState();
      debugPrint('❌ Error en sync: $e');
      return SyncResult.error('Error: $e');
    } finally {
      _isSyncing = false;
      _syncCompleter?.complete();
      _syncCompleter = null;
      _updateSyncState();
    }
  }

  /// Limpia registros antiguos (>2 días, ya sincronizados)
  Future<int> _cleanOldRecords() async {
    try {
      final allMonitoreos = await _db.getAllMonitoreos();
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      int cleaned = 0;

      for (final m in allMonitoreos) {
        final id = m['pmmo_secuencia'] as int?;
        final fechaStr = m['pmmo_fecha'] as String?;
        final isLocal = m['is_local'] as bool? ?? false;
        final needsSync = m['needs_sync'] as bool? ?? false;

        if (id == null || id < 0) continue; // No eliminar temporales
        if (isLocal || needsSync) continue; // No eliminar pendientes

        if (fechaStr != null) {
          final fecha = DateTime.tryParse(fechaStr);
          if (fecha != null && fecha.isBefore(yesterday)) {
            await _db.deleteMonitoreo(id);
            cleaned++;
          }
        }
      }

      debugPrint('🗑️ Limpiados $cleaned registros antiguos');
      return cleaned;
    } catch (e) {
      debugPrint('⚠️ Error limpiando registros: $e');
      return 0;
    }
  }

  /// Prepara un monitoreo local para subir al servidor
  Map<String, dynamic> _prepareForUpload(Map<String, dynamic> m) {
    final id = m['pmmo_secuencia'] as int?;
    return {
      'pmmo_secuencia': (id != null && id > 0) ? id : null,
      'temp_id': id,
      'pmlt_codigo': m['pmlt_codigo'],
      'pmmo_casa': m['pmmo_casa'],
      'pmmo_cantero': m['pmmo_cantero'],
      'pmmo_canteros': m['pmmo_canteros'],
      'pmmo_variedad': m['pmmo_variedad'],
      'pmmo_idvariedad': m['pmmo_idvariedad'],
      'pmmo_grower': m['pmmo_grower'],
      'pmni_nombrecomun': m['pmni_nombrecomun'],
      'pmmo_cantidad': m['pmmo_cantidad'],
      'pmmo_cant_botada': m['pmmo_cant_botada'],
      'pmmo_comentarios': m['pmmo_comentarios'],
      'pmmo_fecha': m['pmmo_fecha'],
      'pmmo_automatico': m['pmmo_automatico'],
      'pmmo_estatus': m['pmmo_estatus'],
      'pmmo_creadopor': m['pmmo_creadopor'],
      'pmmo_contenedor': m['pmmo_contenedor'],
      'pmni_id': m['pmni_id'],
      'pmmo_muestra1': m['pmmo_muestra1'],
      'pmmo_muestra2': m['pmmo_muestra2'],
      'pmmo_muestra3': m['pmmo_muestra3'],
      'pmmo_nivmuestraa1': m['pmmo_nivmuestraa1'],
      'pmmo_nivmuestraa2': m['pmmo_nivmuestraa2'],
      'pmmo_nivmuestraa3': m['pmmo_nivmuestraa3'],
      'pmmo_nivmuestram1': m['pmmo_nivmuestram1'],
      'pmmo_nivmuestram2': m['pmmo_nivmuestram2'],
      'pmmo_nivmuestram3': m['pmmo_nivmuestram3'],
      'idempotency_key': m['idempotency_key'] ??
          'local_${_userId}_${DateTime.now().millisecondsSinceEpoch}',
    };
  }

  /// Guarda un monitoreo localmente (para modo offline)
  Future<int> saveMonitoreoLocal(Map<String, dynamic> monitoreo) async {
    final existingId = monitoreo['pmmo_secuencia'] as int?;
    final isNew = existingId == null || existingId <= 0;

    // Generar ID temporal negativo para nuevos registros
    final id = isNew ? -DateTime.now().millisecondsSinceEpoch : existingId;
    final idempotencyKey = monitoreo['idempotency_key'] as String? ??
        'local_${_userId}_${DateTime.now().millisecondsSinceEpoch}';

    // Preparar datos para guardar
    final dataToSave = Map<String, dynamic>.from(monitoreo);
    dataToSave['pmmo_secuencia'] = id;
    dataToSave['idempotency_key'] = idempotencyKey;
    dataToSave['is_local'] = isNew;
    dataToSave['needs_sync'] = true;
    dataToSave['pmmo_creadopor'] = _userId;

    // Guardar usando OfflineDatabaseService
    await _db.saveMonitoreoFromMap(dataToSave, isLocal: true);
    await _updatePendingCount();

    debugPrint('💾 Guardado local: ID=$id, needsSync=true');
    return id;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Obtiene estadísticas de almacenamiento
  Future<Map<String, int>> getStorageStats() async {
    final allMonitoreos = await _db.getAllMonitoreos();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    int total = allMonitoreos.length;
    int todayCount = 0;
    int yesterdayCount = 0;
    int pendingSync = 0;

    for (final m in allMonitoreos) {
      final fechaStr = m['pmmo_fecha'] as String?;
      final isLocal = m['is_local'] as bool? ?? false;
      final needsSync = m['needs_sync'] as bool? ?? false;
      final id = m['pmmo_secuencia'] as int?;

      if (fechaStr != null) {
        final fecha = DateTime.tryParse(fechaStr);
        if (fecha != null) {
          final fechaDate = DateTime(fecha.year, fecha.month, fecha.day);
          if (fechaDate == today) todayCount++;
          if (fechaDate == yesterday) yesterdayCount++;
        }
      }

      if (isLocal || needsSync || (id != null && id < 0)) {
        pendingSync++;
      }
    }

    return {
      'total': total,
      'today': todayCount,
      'yesterday': yesterdayCount,
      'pending_sync': pendingSync,
    };
  }

  /// Obtiene estadísticas generales
  Future<Map<String, dynamic>> getStats() async {
    final storageStats = await getStorageStats();
    return {
      ...storageStats,
      'last_sync': lastSyncTime.value?.toIso8601String(),
      'status': status.value.name,
      'user_id': _userId,
      'window_days': _windowDays,
    };
  }

  /// Fuerza resync completo
  Future<SyncResult> forceFullResync() async {
    debugPrint('🔄 Forzando resincronización completa...');

    final stats = await getStorageStats();
    if (stats['pending_sync']! > 0) {
      debugPrint(
          '⚠️ Sincronizando ${stats['pending_sync']} pendientes primero...');
      await syncFull();
    }

    await _db.saveSyncMetadata('last_sync_monitoreos', '');
    lastSyncTime.value = null;

    return await syncFull(force: true);
  }

  /// Limpia recursos
  void dispose() {
    stopAutoSync();
    status.dispose();
    pendingCount.dispose();
    lastError.dispose();
    lastSyncTime.dispose();
    syncState.dispose();
  }
}
