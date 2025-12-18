import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/monitoreo_model.dart';
import '../../../services/monitoreo_service.dart';
import '../../../services/intranet_service.dart';
import '../../../services/cache_service.dart';
import '../../../services/offline_database_service.dart';
import '../../../data/datasources/auth_service.dart';

/// Mixin que maneja la carga de datos desde API y SQLite con estrategia offline-first
mixin MonitoreoDataLoaderMixin<T extends StatefulWidget> on State<T> {
  // ===== MÉTODOS ABSTRACTOS =====
  
  /// Si está cargando datos
  bool get isLoading;
  set isLoading(bool value);
  
  /// Servicio de Intranet cacheado
  IntranetService? get cachedIntranetService;
  
  /// Método para mostrar mensajes
  void showMessage(String message);

  // ===== CARGA DE MONITOREOS =====
  
  Future<List<Monitoreo>> loadMonitoreoData() async {
    final monitoreoService = Provider.of<MonitoreoService>(context, listen: false);
    final cacheService = Provider.of<CacheService>(context, listen: false);
    final offlineDbService = Provider.of<OfflineDatabaseService>(context, listen: false);
    final intranetService = cachedIntranetService;
    final authService = Provider.of<AuthService>(context, listen: false);
    
    if (intranetService == null) return [];

    List<Monitoreo> monitoreos = [];

    // Intentar cargar desde API si hay conexión
    if (intranetService.isConnected.value) {
      try {
        monitoreos = await monitoreoService.getMonitoreos();

        // Guardar en SQLite
        for (final m in monitoreos) {
          await offlineDbService.saveMonitoreoFromMap(m.toJson(), isLocal: false);
        }
        debugPrint('💾 ${monitoreos.length} monitoreos guardados en SQLite');

        // Guardar en cache
        await cacheService.saveData(
          'monitoreos_data',
          monitoreos.map((m) => m.toJson()).toList()
        );
        await cacheService.saveData(
          'last_online_sync',
          DateTime.now().toIso8601String()
        );
      } catch (e) {
        debugPrint('⚠️ Error cargando de API, usando SQLite: $e');
        monitoreos = await _loadFromOffline(offlineDbService, cacheService);
      }
    } else {
      // Modo offline
      debugPrint('📴 Modo OFFLINE - Cargando desde SQLite...');
      monitoreos = await _loadFromOffline(offlineDbService, cacheService);
      showMessage('Modo offline - ${monitoreos.length} registros locales');
    }

    // Filtrar por usuario si es necesario
    if (authService.mustFilterByUser && authService.getCurrentUserId() != null) {
      final userId = authService.getCurrentUserId();
      monitoreos = monitoreos.where((m) => m.pmmo_creadopor == userId).toList();
    }

    return monitoreos;
  }

  Future<List<Monitoreo>> _loadFromOffline(
    OfflineDatabaseService offlineDbService,
    CacheService cacheService
  ) async {
    // Intentar SQLite primero
    final sqliteData = await offlineDbService.getAllMonitoreos();
    if (sqliteData.isNotEmpty) {
      debugPrint('📦 ${sqliteData.length} monitoreos cargados desde SQLite');
      return sqliteData.map<Monitoreo>((json) => Monitoreo.fromJson(json)).toList();
    }

    // Fallback a cache
    final cachedData = await cacheService.loadData('monitoreos_data');
    if (cachedData != null && cachedData is List) {
      debugPrint('📦 ${cachedData.length} monitoreos desde cache (fallback)');
      return cachedData.map<Monitoreo>((json) => Monitoreo.fromJson(json)).toList();
    }

    return [];
  }

  // ===== CARGA DE INFO DE LOTE =====
  
  Future<Map<String, dynamic>?> loadLoteInfo(String codigoLote) async {
    final monitoreoService = Provider.of<MonitoreoService>(context, listen: false);
    final offlineDbService = Provider.of<OfflineDatabaseService>(context, listen: false);
    final intranetService = cachedIntranetService;
    
    if (intranetService == null) return null;

    // Buscar en SQLite primero
    dynamic loteInfo = await offlineDbService.getLoteInfo(codigoLote);
    if (loteInfo != null) {
      final estatus = loteInfo['estatus'] ?? loteInfo['pmlt_estatus'] ?? 1;
      if (estatus == 1) {
        debugPrint('📦 Lote $codigoLote encontrado en SQLite');
        return Map<String, dynamic>.from(loteInfo);
      }
    }

    // Si hay conexión, buscar en API
    if (intranetService.isConnected.value) {
      try {
        loteInfo = await monitoreoService.getLoteInfo(codigoLote);
        if (loteInfo != null) {
          final estatus = loteInfo['estatus'] ?? loteInfo['pmlt_estatus'] ?? 1;
          if (estatus == 1) {
            await offlineDbService.saveLoteInfo(
              codigoLote,
              Map<String, dynamic>.from(loteInfo)
            );
            debugPrint('💾 Lote $codigoLote guardado en SQLite');
            return Map<String, dynamic>.from(loteInfo);
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error consultando API: $e');
      }
    }

    return null;
  }

  // ===== CARGA DE INFO DE PLAGA =====
  
  Future<void> loadInfoPlagaAction(String nombrePlaga) async {
    try {
      final monitoreoService = Provider.of<MonitoreoService>(context, listen: false);
      final nivelesData = await monitoreoService.getNivelesPlaga(nombrePlaga);
      
      if (mounted && nivelesData.isNotEmpty) {
        // Este método debe ser implementado en el State para actualizar los límites
        _updateNivelesLimites(
          nivelesData['lmsupniv1'] ?? 10,
          nivelesData['lmsupniv2'] ?? 20,
          nivelesData['lmsupniv3'] ?? 30,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error cargando niveles de plaga: $e');
    }
  }

  // Este método debe ser implementado en el State
  void _updateNivelesLimites(int nivel1, int nivel2, int nivel3);
}