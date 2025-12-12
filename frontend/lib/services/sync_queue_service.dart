// lib/services/sync_queue_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../data/database/app_database.dart';

class SyncQueueService extends ChangeNotifier {
  final AppDatabase _database;
  final Dio _dio;
  final String _baseUrl;

  bool _isSyncing = false;
  int _pendingCount = 0;
  String? _lastError;
  DateTime? _lastSyncAttempt;

  // CORREGIDO: Para connectivity_plus 5.0.2
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _retryTimer;

  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingCount;
  String? get lastError => _lastError;
  DateTime? get lastSyncAttempt => _lastSyncAttempt;
  bool get hasPendingOperations => _pendingCount > 0;

  SyncQueueService({
    required AppDatabase database,
    required Dio dio,
    required String baseUrl,
  })  : _database = database,
        _dio = dio,
        _baseUrl = baseUrl {
    _initialize();
  }

  Future<void> _initialize() async {
    await _updatePendingCount();
    _startConnectivityListener();
    _startRetryTimer();
  }

  void _startConnectivityListener() {
    // CORREGIDO: Para connectivity_plus 5.0.2 (result es ConnectivityResult, no List)
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      final hasConnection = result != ConnectivityResult.none;
      if (hasConnection && _pendingCount > 0) {
        debugPrint('📶 Conectividad restaurada, iniciando sincronización...');
        syncPendingOperations();
      }
    });
  }

  void _startRetryTimer() {
    _retryTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_pendingCount > 0 && !_isSyncing) {
        debugPrint('⏰ Reintento automático de sincronización...');
        syncPendingOperations();
      }
    });
  }

  Future<void> _updatePendingCount() async {
    _pendingCount = await _database.countPendingOperations();
    notifyListeners();
  }

  String generateIdempotencyKey(int userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(9999).toString().padLeft(4, '0');
    return '${userId}_${timestamp}_$random';
  }

  int generateTempId(int userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return -(timestamp * 100 + userId % 100);
  }

  // ========================================================================
  // OPERACIONES DE COLA
  // ========================================================================

  Future<int> enqueueCreate({
    required int userId,
    required Map<String, dynamic> monitoreoData,
  }) async {
    final idempotencyKey = generateIdempotencyKey(userId);
    final tempId = generateTempId(userId);

    monitoreoData['idempotency_key'] = idempotencyKey;
    monitoreoData['temp_id'] = tempId;

    debugPrint(
        '📥 Encolando CREATE: idempotency_key=$idempotencyKey, tempId=$tempId');

    await _database.addToOutbox(
      idempotencyKey: idempotencyKey,
      userId: userId,
      operation: 'create',
      payload: jsonEncode(monitoreoData),
      tempId: tempId,
    );

    await _updatePendingCount();
    _trySyncInBackground();

    return tempId;
  }

  Future<void> enqueueUpdate({
    required int userId,
    required int monitoreoId,
    required Map<String, dynamic> monitoreoData,
    int? expectedVersion,
  }) async {
    final idempotencyKey = generateIdempotencyKey(userId);

    monitoreoData['expected_version'] = expectedVersion;
    monitoreoData['pmmo_secuencia'] = monitoreoId;

    debugPrint('📥 Encolando UPDATE para monitoreo $monitoreoId');

    await _database.addToOutbox(
      idempotencyKey: idempotencyKey,
      userId: userId,
      operation: 'update',
      payload: jsonEncode(monitoreoData),
    );

    await _updatePendingCount();
    _trySyncInBackground();
  }

  Future<void> enqueueDelete({
    required int userId,
    required int monitoreoId,
  }) async {
    final idempotencyKey = generateIdempotencyKey(userId);

    debugPrint('📥 Encolando DELETE para monitoreo $monitoreoId');

    await _database.addToOutbox(
      idempotencyKey: idempotencyKey,
      userId: userId,
      operation: 'delete',
      payload: jsonEncode({'pmmo_secuencia': monitoreoId}),
    );

    await _updatePendingCount();
    _trySyncInBackground();
  }

  void _trySyncInBackground() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_isSyncing) {
        syncPendingOperations();
      }
    });
  }

  // ========================================================================
  // SINCRONIZACIÓN
  // ========================================================================

  Future<SyncResult> syncPendingOperations() async {
    if (_isSyncing) {
      debugPrint('⏳ Ya hay una sincronización en proceso');
      return SyncResult(success: false, message: 'Sincronización en proceso');
    }

    // CORREGIDO: Para connectivity_plus 5.0.2
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      debugPrint('📵 Sin conexión, sincronización pospuesta');
      return SyncResult(success: false, message: 'Sin conexión a internet');
    }

    _isSyncing = true;
    _lastSyncAttempt = DateTime.now();
    _lastError = null;
    notifyListeners();

    int synced = 0;
    int failed = 0;
    final List<SyncOperationResult> results = [];

    try {
      final pendingOps = await _database.getPendingOperations();
      debugPrint(
          '🔄 Sincronizando ${pendingOps.length} operaciones pendientes...');

      for (final op in pendingOps) {
        try {
          await _database.markOperationSyncing(op.id);

          final result = await _processOperation(op);

          if (result.success) {
            await _database.markOperationCompleted(op.id, result.serverId);
            synced++;
            debugPrint('✅ Operación ${op.id} sincronizada');
          } else {
            await _database.markOperationFailed(
                op.id, result.error ?? 'Error desconocido');
            failed++;
            debugPrint('❌ Operación ${op.id} falló: ${result.error}');
          }

          results.add(result);
        } catch (e) {
          await _database.markOperationFailed(op.id, e.toString());
          failed++;
          results.add(SyncOperationResult(
            operationId: op.id,
            success: false,
            error: e.toString(),
          ));
          debugPrint('❌ Error procesando operación ${op.id}: $e');
        }
      }

      await _database.clearCompletedOperations();

      if (synced > 0) {
        await _database.saveLastSyncTime();
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('❌ Error general en sincronización: $e');
    } finally {
      _isSyncing = false;
      await _updatePendingCount();
      notifyListeners();
    }

    final message =
        'Sincronización completada: $synced exitosos, $failed fallidos';
    debugPrint('📊 $message');

    return SyncResult(
      success: failed == 0,
      message: message,
      synced: synced,
      failed: failed,
      results: results,
    );
  }

  Future<SyncOperationResult> _processOperation(OutboxData op) async {
    final payload = jsonDecode(op.payload) as Map<String, dynamic>;

    switch (op.operation) {
      case 'create':
        return await _processCreate(op, payload);
      case 'update':
        return await _processUpdate(op, payload);
      case 'delete':
        return await _processDelete(op, payload);
      default:
        return SyncOperationResult(
          operationId: op.id,
          success: false,
          error: 'Operación desconocida: ${op.operation}',
        );
    }
  }

  Future<SyncOperationResult> _processCreate(
      OutboxData op, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/monitoreo',
        data: payload,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final serverId = data['data']?['pmmo_secuencia'] as int?;
          final isIdempotent = data['idempotent'] == true;

          if (op.tempId != null && serverId != null) {
            await _database.updateTempIdToServerId(op.tempId!, serverId);
          }

          return SyncOperationResult(
            operationId: op.id,
            success: true,
            serverId: serverId,
            tempId: op.tempId,
            isIdempotent: isIdempotent,
          );
        } else {
          return SyncOperationResult(
            operationId: op.id,
            success: false,
            error: data['message'] ?? 'Error del servidor',
          );
        }
      } else {
        return SyncOperationResult(
          operationId: op.id,
          success: false,
          error: 'HTTP ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final existingId = e.response?.data['existing_id'];
        return SyncOperationResult(
          operationId: op.id,
          success: true,
          serverId: existingId,
          isIdempotent: true,
        );
      }
      return SyncOperationResult(
        operationId: op.id,
        success: false,
        error: e.message ?? 'Error de conexión',
      );
    }
  }

  Future<SyncOperationResult> _processUpdate(
      OutboxData op, Map<String, dynamic> payload) async {
    try {
      final monitoreoId = payload['pmmo_secuencia'];

      final response = await _dio.put(
        '$_baseUrl/monitoreo/$monitoreoId',
        data: payload,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final newVersion = data['new_version'] as int?;
          return SyncOperationResult(
            operationId: op.id,
            success: true,
            serverId: monitoreoId,
            newVersion: newVersion,
          );
        } else {
          if (data['conflict'] == true) {
            return SyncOperationResult(
              operationId: op.id,
              success: false,
              error: 'Conflicto de versión: ${data['message']}',
              isConflict: true,
              currentVersion: data['current_version'],
            );
          }
          return SyncOperationResult(
            operationId: op.id,
            success: false,
            error: data['message'] ?? 'Error del servidor',
          );
        }
      } else {
        return SyncOperationResult(
          operationId: op.id,
          success: false,
          error: 'HTTP ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        return SyncOperationResult(
          operationId: op.id,
          success: false,
          error: 'Conflicto de versión',
          isConflict: true,
          currentVersion: e.response?.data['current_version'],
        );
      }
      return SyncOperationResult(
        operationId: op.id,
        success: false,
        error: e.message ?? 'Error de conexión',
      );
    }
  }

  Future<SyncOperationResult> _processDelete(
      OutboxData op, Map<String, dynamic> payload) async {
    try {
      final monitoreoId = payload['pmmo_secuencia'];

      final response = await _dio.delete(
        '$_baseUrl/monitoreo/$monitoreoId',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          await _database.deleteMonitoreoLocal(monitoreoId);
          return SyncOperationResult(
            operationId: op.id,
            success: true,
          );
        } else {
          return SyncOperationResult(
            operationId: op.id,
            success: false,
            error: data['message'] ?? 'Error del servidor',
          );
        }
      } else {
        return SyncOperationResult(
          operationId: op.id,
          success: false,
          error: 'HTTP ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return SyncOperationResult(
          operationId: op.id,
          success: true,
        );
      }
      return SyncOperationResult(
        operationId: op.id,
        success: false,
        error: e.message ?? 'Error de conexión',
      );
    }
  }

  // ========================================================================
  // UTILIDADES
  // ========================================================================

  Future<bool> isOperationProcessed(String idempotencyKey) async {
    final op = await _database.findByIdempotencyKey(idempotencyKey);
    return op?.status == 'completed';
  }

  Future<Map<String, dynamic>> getSyncStats() async {
    final dbStats = await _database.getDatabaseStats();
    final lastSync = await _database.getLastSyncTime();

    return {
      'pending_operations': dbStats['pending_operations'],
      'monitoreos_locales': dbStats['monitoreos_locales'],
      'last_sync': lastSync?.toIso8601String(),
      'is_syncing': _isSyncing,
      'last_error': _lastError,
    };
  }

  Future<SyncResult> forceSyncNow() async {
    debugPrint('🔄 Forzando sincronización manual...');
    return await syncPendingOperations();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}

// ========================================================================
// CLASES DE RESULTADO
// ========================================================================

class SyncResult {
  final bool success;
  final String message;
  final int synced;
  final int failed;
  final List<SyncOperationResult> results;

  SyncResult({
    required this.success,
    required this.message,
    this.synced = 0,
    this.failed = 0,
    this.results = const [],
  });
}

class SyncOperationResult {
  final int operationId;
  final bool success;
  final int? serverId;
  final int? tempId;
  final int? newVersion;
  final String? error;
  final bool isIdempotent;
  final bool isConflict;
  final int? currentVersion;

  SyncOperationResult({
    required this.operationId,
    required this.success,
    this.serverId,
    this.tempId,
    this.newVersion,
    this.error,
    this.isIdempotent = false,
    this.isConflict = false,
    this.currentVersion,
  });
}
