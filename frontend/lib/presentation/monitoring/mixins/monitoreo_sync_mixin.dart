import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/monitoreo_model.dart';
import '../../../services/monitoreo_service.dart';
import '../../../services/intranet_service.dart';
import '../../../services/cache_service.dart';
import '../../../services/offline_database_service.dart';

/// Mixin que maneja la sincronización de cambios pendientes y conectividad
mixin MonitoreoSyncMixin<T extends StatefulWidget> on State<T> {
  // ===== VARIABLES DE SINCRONIZACIÓN =====
  bool _isSyncing = false;
  int _pendingChangesCount = 0;
  String _lastSyncStatus = '';

  // ===== GETTERS =====
  bool get isSyncing => _isSyncing;
  int get pendingChangesCount => _pendingChangesCount;
  String get lastSyncStatus => _lastSyncStatus;

  // ===== MÉTODOS ABSTRACTOS =====
  
  /// Servicio de Intranet cacheado
  IntranetService? get cachedIntranetService;
  
  /// Método para mostrar mensajes
  void showMessage(String message);
  
  /// Método para recargar datos
  Future<void> loadData();

  // ===== ACTUALIZACIÓN DE CONTEO =====
  
  Future<void> updatePendingChangesCount() async {
    if (!mounted) return;
    
    final cacheService = Provider.of<CacheService>(context, listen: false);
    final pendingChanges = await cacheService.loadData('pending_monitoreos') ?? [];
    
    if (mounted) {
      setState(() {
        _pendingChangesCount = pendingChanges is List ? pendingChanges.length : 0;
      });
    }
  }

  // ===== LISTENER DE CONECTIVIDAD =====
  
  void setupConnectivityListener() {
    cachedIntranetService?.isConnected.addListener(_handleConnectivityChange);
  }

  void cleanupConnectivityListener() {
    cachedIntranetService?.isConnected.removeListener(_handleConnectivityChange);
  }

  void _handleConnectivityChange() async {
    if (!mounted) return;
    
    final intranetService = cachedIntranetService;
    if (intranetService == null) return;

    final isOnline = intranetService.isConnected.value;
    debugPrint('🌐 Conectividad cambió: ${isOnline ? "ONLINE" : "OFFLINE"}');

    if (isOnline) {
      // Si hay cambios pendientes, ofrecer sincronizar
      if (_pendingChangesCount > 0 && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.wifi, color: Colors.green),
                SizedBox(width: 8),
                Text('Conexión restablecida'),
              ],
            ),
            content: Text(
              '$_pendingChangesCount cambios pendientes. ¿Sincronizar ahora?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Después'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  sincronizarCambiosPendientes();
                },
                icon: const Icon(Icons.sync),
                label: const Text('Sincronizar'),
              ),
            ],
          ),
        );
      }
      await loadData();
    } else {
      debugPrint('📴 Modo OFFLINE - Usando datos locales');
      showMessage('Sin conexión - Usando datos locales');
      await loadData();
    }
  }

  // ===== SINCRONIZACIÓN =====
  
  Future<void> sincronizarCambiosPendientes() async {
    if (!mounted) return;
    
    final intranetService = cachedIntranetService;
    if (intranetService == null || !intranetService.isConnected.value) {
      showMessage('Sin conexión');
      return;
    }

    setState(() {
      _isSyncing = true;
      _lastSyncStatus = 'Sincronizando...';
    });

    try {
      final cacheService = Provider.of<CacheService>(context, listen: false);
      final monitoreoService = Provider.of<MonitoreoService>(context, listen: false);
      final offlineDbService = Provider.of<OfflineDatabaseService>(context, listen: false);

      // Cargar cambios pendientes
      final cachedPending = await cacheService.loadData('pending_monitoreos');
      if (cachedPending == null || cachedPending is! List || cachedPending.isEmpty) {
        setState(() {
          _isSyncing = false;
          _lastSyncStatus = 'Sin cambios pendientes';
        });
        return;
      }

      List<dynamic> pendingChanges = cachedPending;
      List<dynamic> failedChanges = [];
      List<int> syncedTempIds = [];
      int successCount = 0;

      // Procesar cada cambio
      for (final change in pendingChanges) {
        try {
          final operation = change['operation'];
          final monitoreo = Monitoreo.fromJson(change['monitoreo']);
          final tempId = monitoreo.pmmo_secuencia;

          if (operation == 'create') {
            if (monitoreo.isTemporary()) {
              await monitoreoService.crearMonitoreo(
                monitoreo.copyWith(pmmo_secuencia: null, isOfflineCreated: false)
              );
              if (tempId != null) syncedTempIds.add(tempId);
            } else {
              await monitoreoService.crearMonitoreo(monitoreo);
            }
            successCount++;
          } else if (operation == 'update') {
            if (monitoreo.isTemporary()) {
              await monitoreoService.crearMonitoreo(
                monitoreo.copyWith(pmmo_secuencia: null, isOfflineCreated: false)
              );
              if (tempId != null) syncedTempIds.add(tempId);
            } else {
              await monitoreoService.actualizarMonitoreo(monitoreo);
            }
            successCount++;
          } else if (operation == 'delete') {
            if (!monitoreo.isTemporary()) {
              await monitoreoService.eliminarMonitoreo(monitoreo.pmmo_secuencia!);
            }
            if (tempId != null) syncedTempIds.add(tempId);
            successCount++;
          }
        } catch (e) {
          debugPrint('⚠️ Error sincronizando cambio: $e');
          failedChanges.add(change);
        }
      }

      // Limpiar registros temporales sincronizados de SQLite
      for (final tempId in syncedTempIds) {
        try {
          await offlineDbService.deleteMonitoreo(tempId);
          debugPrint('🗑️ Eliminado de SQLite: $tempId (sincronizado)');
        } catch (e) {
          debugPrint('⚠️ No se pudo eliminar $tempId de SQLite: $e');
        }
      }

      // Actualizar cambios pendientes
      await cacheService.saveData('pending_monitoreos', failedChanges);
      await updatePendingChangesCount();
      await loadData();

      if (mounted) {
        setState(() {
          _isSyncing = false;
          _lastSyncStatus = failedChanges.isEmpty
              ? 'Sincronización completa'
              : 'Sincronización parcial';
        });
        
        showMessage(
          failedChanges.isEmpty
              ? 'Sincronizado correctamente'
              : 'Sincronización parcial: ${failedChanges.length} cambios pendientes'
        );
      }
    } catch (e) {
      debugPrint('❌ Error en sincronización: $e');
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _lastSyncStatus = 'Error: $e';
        });
        showMessage('Error en sincronización');
      }
    }
  }

  // ===== REGISTRO DE CAMBIO PENDIENTE =====
  
  Future<void> registerPendingChange(
    String operation,
    Monitoreo monitoreo,
  ) async {
    final cacheService = Provider.of<CacheService>(context, listen: false);
    
    List<dynamic> pendingChanges = [];
    final cachedPending = await cacheService.loadData('pending_monitoreos');
    if (cachedPending != null && cachedPending is List) {
      pendingChanges = cachedPending;
    }

    pendingChanges.add({
      'operation': operation,
      'monitoreo': monitoreo.toJson(),
      'timestamp': DateTime.now().toIso8601String(),
    });

    await cacheService.saveData('pending_monitoreos', pendingChanges);
    await updatePendingChangesCount();
    
    debugPrint('📝 Cambio pendiente registrado: $operation');
  }
}