// lib/services/sincro_service.dart
import 'package:flutter/foundation.dart';
import '../models/monitoreo_model.dart';
import 'monitoreo_service.dart';
import 'intranet_service.dart';
import 'sync_queue_service.dart';

class SincronizacionService {
  final MonitoreoService _monitoreoService;
  final IntranetService _intranetService;
  final SyncQueueService _syncQueueService;

  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  final ValueNotifier<int> pendingChangesCount = ValueNotifier<int>(0);
  final ValueNotifier<String> lastSyncStatus = ValueNotifier<String>('');

  SincronizacionService({
    required MonitoreoService monitoreoService,
    required IntranetService intranetService,
    required SyncQueueService syncQueueService,
  })  : _monitoreoService = monitoreoService,
        _intranetService = intranetService,
        _syncQueueService = syncQueueService {
    debugPrint('📦 SincronizacionService inicializado con SQLite');

    _updatePendingChangesCount();
    _intranetService.isConnected.addListener(_handleConnectivityChange);
    _syncQueueService.addListener(_onSyncQueueChanged);
  }

  void _onSyncQueueChanged() {
    _updatePendingChangesCount();
    isSyncing.value = _syncQueueService.isSyncing;
  }

  void _handleConnectivityChange() {
    if (_intranetService.isConnected.value) {
      debugPrint('📶 Conexión restaurada, iniciando sincronización...');
      sincronizarCambiosPendientes();
    }
  }

  Future<void> _updatePendingChangesCount() async {
    pendingChangesCount.value = _syncQueueService.pendingCount;
    debugPrint('📊 Cambios pendientes: ${pendingChangesCount.value}');
  }

  Future<bool> sincronizarCambiosPendientes() async {
    if (isSyncing.value || !_intranetService.isConnected.value) {
      debugPrint(
          '⏳ No se puede sincronizar: ${isSyncing.value ? "Ya sincronizando" : "Sin conexión"}');
      return false;
    }

    try {
      isSyncing.value = true;
      lastSyncStatus.value = 'Sincronizando...';

      debugPrint('🔄 Iniciando sincronización...');
      debugPrint(
          '   Operaciones pendientes: ${_syncQueueService.pendingCount}');

      final result = await _syncQueueService.syncPendingOperations();

      if (result.success) {
        lastSyncStatus.value =
            'Sincronización completada: ${result.synced} registros';
      } else {
        lastSyncStatus.value = result.message;
      }

      debugPrint('✅ Resultado sincronización:');
      debugPrint('   Éxito: ${result.success}');
      debugPrint('   Sincronizados: ${result.synced}');
      debugPrint('   Fallidos: ${result.failed}');

      await _updatePendingChangesCount();

      // Recargar datos del servidor
      if (result.synced > 0) {
        try {
          await _monitoreoService.getMonitoreos();
        } catch (e) {
          debugPrint('⚠️ Error actualizando datos: $e');
        }
      }

      return result.success;
    } catch (e) {
      debugPrint('❌ Error en sincronización: $e');
      lastSyncStatus.value = 'Error: $e';
      return false;
    } finally {
      isSyncing.value = false;
    }
  }

  Future<void> registrarCambioLocal(
      String operacion, Monitoreo monitoreo) async {
    debugPrint(
        '📝 Registrando cambio local: $operacion, ID: ${monitoreo.pmmo_secuencia}');

    final userId = monitoreo.pmmo_creadopor ?? 0;

    switch (operacion) {
      case 'create':
        await _syncQueueService.enqueueCreate(
          userId: userId,
          monitoreoData: monitoreo.toJson(),
        );
        break;
      case 'update':
        await _syncQueueService.enqueueUpdate(
          userId: userId,
          monitoreoId: monitoreo.pmmo_secuencia ?? 0,
          monitoreoData: monitoreo.toJson(),
        );
        break;
      case 'delete':
        await _syncQueueService.enqueueDelete(
          userId: userId,
          monitoreoId: monitoreo.pmmo_secuencia ?? 0,
        );
        break;
    }

    await _updatePendingChangesCount();
  }

  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    return await _syncQueueService.getSyncStats();
  }

  Future<bool> forzarSincronizacion() async {
    debugPrint('🔄 Forzando sincronización manual...');
    return await sincronizarCambiosPendientes();
  }

  bool get hayCambiosPendientes => pendingChangesCount.value > 0;

  void dispose() {
    _intranetService.isConnected.removeListener(_handleConnectivityChange);
    _syncQueueService.removeListener(_onSyncQueueChanged);
    isSyncing.dispose();
    pendingChangesCount.dispose();
    lastSyncStatus.dispose();
  }
}
