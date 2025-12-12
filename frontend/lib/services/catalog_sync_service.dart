// lib/services/catalog_sync_service.dart
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/config/flavor_config.dart';
import 'offline_database_service.dart';
import 'intranet_service.dart';

class CatalogSyncService extends ChangeNotifier {
  final OfflineDatabaseService _offlineDbService;
  final IntranetService _intranetService;
  final ApiConfig _apiConfig;
  final Dio _dio;

  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  Map<String, int> _localCounts = {};
  Map<String, int> _serverCounts = {};
  String? _lastError;

  CatalogSyncService({
    required OfflineDatabaseService offlineDbService,
    required IntranetService intranetService,
    required ApiConfig apiConfig,
  })  : _offlineDbService = offlineDbService,
        _intranetService = intranetService,
        _apiConfig = apiConfig,
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        )) {
    // Escuchar cambios de conexión
    _intranetService.isConnected.addListener(_onConnectionChanged);
    // Cargar última sincronización
    _loadLastSyncTime();
  }

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  Map<String, int> get localCounts => _localCounts;
  Map<String, int> get serverCounts => _serverCounts;
  String? get lastError => _lastError;
  bool get hasCatalogs => _localCounts.values.any((count) => count > 0);

  Future<void> _loadLastSyncTime() async {
    final savedTime = await _offlineDbService.getMetadata('last_catalog_sync');
    if (savedTime != null) {
      _lastSyncTime = DateTime.tryParse(savedTime);
      notifyListeners();
    }
  }

  void _onConnectionChanged() {
    if (_intranetService.isConnected.value) {
      // Cuando se recupera la conexión, sincronizar silenciosamente
      syncCatalogsIfNeeded();
    }
  }

  /// Sincroniza catálogos si es necesario (compara counts)
  Future<bool> syncCatalogsIfNeeded() async {
    if (_isSyncing) return false;
    if (!_intranetService.isConnected.value) return false;

    try {
      _isSyncing = true;
      _lastError = null;
      notifyListeners();

      debugPrint('🔄 Verificando sincronización de catálogos...');

      // 1. Obtener counts del servidor
      final serverCounts = await _getServerCounts();
      if (serverCounts == null) {
        debugPrint('⚠️ No se pudo obtener counts del servidor');
        _isSyncing = false;
        notifyListeners();
        return false;
      }
      _serverCounts = serverCounts;

      // 2. Obtener counts locales
      _localCounts = await _getLocalCounts();

      // 3. Comparar y decidir qué sincronizar
      bool needsSync = false;
      List<String> catalogsToSync = [];

      for (final catalog in [
        'variedades',
        'lotes',
        'plagas',
        'unidades_cultivo'
      ]) {
        final localCount = _localCounts[catalog] ?? 0;
        final serverCount = _serverCounts[catalog] ?? 0;

        if (serverCount != localCount) {
          needsSync = true;
          catalogsToSync.add(catalog);
          debugPrint(
              '📊 $catalog: local=$localCount, servidor=$serverCount → SINCRONIZAR');
        } else {
          debugPrint(
              '✅ $catalog: local=$localCount, servidor=$serverCount → OK');
        }
      }

      // 4. Si hay diferencias o es primera vez, descargar todo
      if (needsSync || _lastSyncTime == null) {
        debugPrint(
            '🔄 Sincronizando catálogos: ${catalogsToSync.isEmpty ? "INICIAL" : catalogsToSync.join(", ")}');
        await _downloadAllCatalogs();
      } else {
        debugPrint('✅ Catálogos sincronizados, no hay cambios');
      }

      _lastSyncTime = DateTime.now();
      await _offlineDbService.saveMetadata(
          'last_catalog_sync', _lastSyncTime!.toIso8601String());

      // Actualizar counts locales después de sync
      _localCounts = await _getLocalCounts();

      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error sincronizando catálogos: $e');
      _lastError = e.toString();
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  /// Fuerza sincronización completa
  Future<bool> forceFullSync() async {
    if (_isSyncing) return false;
    if (!_intranetService.isConnected.value) {
      _lastError = 'Sin conexión a internet';
      notifyListeners();
      return false;
    }

    try {
      _isSyncing = true;
      _lastError = null;
      notifyListeners();

      debugPrint('🔄 Forzando sincronización completa de catálogos...');
      await _downloadAllCatalogs();

      _lastSyncTime = DateTime.now();
      await _offlineDbService.saveMetadata(
          'last_catalog_sync', _lastSyncTime!.toIso8601String());

      _localCounts = await _getLocalCounts();

      _isSyncing = false;
      notifyListeners();
      debugPrint('✅ Sincronización forzada completada');
      return true;
    } catch (e) {
      debugPrint('❌ Error en sincronización forzada: $e');
      _lastError = e.toString();
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, int>?> _getServerCounts() async {
    try {
      final response =
          await _dio.get('${_apiConfig.apiUrl}/catalogos-sync/counts');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        return {
          'variedades': data['variedades'] ?? 0,
          'lotes': data['lotes'] ?? 0,
          'plagas': data['plagas'] ?? 0,
          'unidades_cultivo': data['unidades_cultivo'] ?? 0,
        };
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error obteniendo counts del servidor: $e');
      return null;
    }
  }

  Future<Map<String, int>> _getLocalCounts() async {
    final variedades = await _offlineDbService.getVariedades();
    final lotes = await _offlineDbService.getCatalogo('lotes');
    final plagas = await _offlineDbService.getPlagas();
    final unidades = await _offlineDbService.getCasas();

    return {
      'variedades': (variedades as List?)?.length ?? 0,
      'lotes': (lotes is List) ? lotes.length : 0,
      'plagas': plagas?.length ?? 0,
      'unidades_cultivo': (unidades as List?)?.length ?? 0,
    };
  }

  /// Descarga catálogos de forma incremental para evitar bloquear el browser
  Future<void> _downloadAllCatalogs() async {
    debugPrint('📥 Iniciando descarga incremental de catálogos...');
    final baseUrl = _apiConfig.apiUrl;

    // 1. Plagas (más pequeño ~34 registros)
    debugPrint('📦 Sincronizando plagas...');
    await _downloadAndSavePlagas(baseUrl);
    await Future.delayed(const Duration(milliseconds: 100));

    // 2. Unidades de cultivo (~102 registros)
    debugPrint('📦 Sincronizando unidades de cultivo...');
    await _downloadAndSaveUnidades(baseUrl);
    await Future.delayed(const Duration(milliseconds: 100));

    // 3. Variedades (~656 registros)
    debugPrint('📦 Sincronizando variedades...');
    await _downloadAndSaveVariedades(baseUrl);
    await Future.delayed(const Duration(milliseconds: 100));

    // 4. Lotes (~1449 registros - el más grande)
    debugPrint('📦 Sincronizando lotes...');
    await _downloadAndSaveLotes(baseUrl);
    await Future.delayed(const Duration(milliseconds: 100));

    // 5. Niveles de infestación
    debugPrint('📦 Sincronizando niveles de infestación...');
    await _downloadAndSaveNiveles(baseUrl);

    debugPrint('📥 ✅ Descarga incremental completada');
  }

  Future<void> _downloadAndSavePlagas(String baseUrl) async {
    try {
      final response = await _dio.get('$baseUrl/plagas');
      if (response.statusCode == 200) {
        final data = response.data;
        List plagas;

        if (data is Map && data['success'] == true) {
          plagas = data['data'] ?? [];
        } else if (data is List) {
          plagas = data;
        } else {
          plagas = [];
        }

        // ✅ FILTRAR: Solo plagas ACTIVAS (estatus = 1)
        final plagasActivas = plagas.where((p) {
          final estatus = p['pmpl_estatus'] ?? p['estatus'] ?? 1;
          return estatus == 1;
        }).toList();

        final plagasNombres = plagasActivas
            .map((p) => p['pmpl_nombrecomun']?.toString() ?? '')
            .where((n) => n.isNotEmpty)
            .toList();

        await _offlineDbService.savePlagas(plagasNombres.cast<String>());

        // Guardar catálogo completo (solo activas) para referencia
        await _offlineDbService.saveCatalogo('plagas', plagasActivas);

        debugPrint(
            '✅ Plagas: ${plagasNombres.length} activas (${plagas.length - plagasActivas.length} inactivas filtradas)');
      }
    } catch (e) {
      debugPrint('⚠️ Error descargando plagas: $e');
    }
  }

  Future<void> _downloadAndSaveUnidades(String baseUrl) async {
    try {
      final response = await _dio.get('$baseUrl/unidadesCultivo');
      if (response.statusCode == 200) {
        final data = response.data;
        List unidades;

        if (data is Map && data['success'] == true) {
          unidades = data['data'] ?? [];
        } else if (data is List) {
          unidades = data;
        } else {
          unidades = [];
        }

        // ✅ FILTRAR: Solo unidades ACTIVAS (estatus = 1)
        final unidadesActivas = unidades.where((u) {
          final estatus = u['pmun_estatus'] ?? u['estatus'] ?? 1;
          return estatus == 1;
        }).toList();

        await _offlineDbService.saveCasas(unidadesActivas);
        debugPrint(
            '✅ Unidades: ${unidadesActivas.length} activas (${unidades.length - unidadesActivas.length} inactivas filtradas)');
      }
    } catch (e) {
      debugPrint('⚠️ Error descargando unidades: $e');
    }
  }

  Future<void> _downloadAndSaveVariedades(String baseUrl) async {
    try {
      final response = await _dio.get('$baseUrl/variedades');
      if (response.statusCode == 200) {
        final data = response.data;
        List variedades;

        if (data is Map && data['success'] == true) {
          variedades = data['data'] ?? [];
        } else if (data is List) {
          variedades = data;
        } else {
          variedades = [];
        }

        // ✅ FILTRAR: Solo variedades ACTIVAS (estatus = 1)
        final variedadesActivas = variedades.where((v) {
          final estatus = v['pmva_estatus'] ?? v['estatus'] ?? 1;
          return estatus == 1;
        }).toList();

        await _offlineDbService.saveVariedades(variedadesActivas);
        debugPrint(
            '✅ Variedades: ${variedadesActivas.length} activas (${variedades.length - variedadesActivas.length} inactivas filtradas)');
      }
    } catch (e) {
      debugPrint('⚠️ Error descargando variedades: $e');
    }
  }

  Future<void> _downloadAndSaveLotes(String baseUrl) async {
    try {
      final response = await _dio.get('$baseUrl/lotes');
      if (response.statusCode == 200) {
        final data = response.data;
        List lotes;

        if (data is Map && data['success'] == true) {
          lotes = data['data'] ?? [];
        } else if (data is List) {
          lotes = data;
        } else {
          lotes = [];
        }

        // ✅ FILTRAR: Solo lotes ACTIVOS (estatus = 1)
        final lotesActivos = lotes.where((l) {
          final estatus = l['pmlt_estatus'] ?? l['estatus'] ?? 1;
          return estatus == 1;
        }).toList();

        await _offlineDbService.saveCatalogo('lotes', lotesActivos);
        debugPrint(
            '✅ Lotes: ${lotesActivos.length} activos (${lotes.length - lotesActivos.length} inactivos filtrados)');
      }
    } catch (e) {
      debugPrint('⚠️ Error descargando lotes: $e');
    }
  }

  Future<void> _downloadAndSaveNiveles(String baseUrl) async {
    try {
      final response = await _dio.get('$baseUrl/nivelesinfestacion');
      if (response.statusCode == 200) {
        final data = response.data;
        List niveles;

        if (data is Map && data['success'] == true) {
          niveles = data['data'] ?? [];
        } else if (data is List) {
          niveles = data;
        } else {
          niveles = [];
        }

        // ✅ FILTRAR: Solo niveles de plagas ACTIVAS
        final nivelesActivos = niveles.where((n) {
          final estatus = n['pmni_estatus'] ?? n['estatus'] ?? 1;
          return estatus == 1;
        }).toList();

        // Agrupar por plaga para acceso rápido
        final nivelesMap = <String, List<dynamic>>{};
        for (final nivel in nivelesActivos) {
          final plaga = nivel['pmni_nombrecomun']?.toString() ?? 'unknown';
          if (!nivelesMap.containsKey(plaga)) {
            nivelesMap[plaga] = [];
          }
          nivelesMap[plaga]!.add(nivel);
        }

        await _offlineDbService.saveNivelesLimites(nivelesMap);
        debugPrint(
            '✅ Niveles: ${nivelesActivos.length} activos (${nivelesMap.keys.length} plagas)');
      }
    } catch (e) {
      debugPrint('⚠️ Error descargando niveles: $e');
    }
  }
  // ========================================================================
  // MÉTODOS DE ACCESO A CATÁLOGOS (con fallback a servidor)
  // ========================================================================

  /// Obtener variedades (primero local, luego servidor si está vacío)
  Future<List<dynamic>> getVariedades() async {
    final local = await _offlineDbService.getVariedades();
    if (local != null && local.isNotEmpty) {
      return local;
    }

    if (_intranetService.isConnected.value) {
      await syncCatalogsIfNeeded();
      return await _offlineDbService.getVariedades() ?? [];
    }

    return [];
  }

  /// Obtener lotes
  Future<List<dynamic>> getLotes() async {
    final local = await _offlineDbService.getCatalogo('lotes');
    if (local is List && local.isNotEmpty) {
      return local;
    }

    if (_intranetService.isConnected.value) {
      await syncCatalogsIfNeeded();
      final updated = await _offlineDbService.getCatalogo('lotes');
      return updated is List ? updated : [];
    }

    return [];
  }

  /// Obtener plagas
  Future<List<String>> getPlagas() async {
    final local = await _offlineDbService.getPlagas();
    if (local != null && local.isNotEmpty) {
      return local;
    }

    if (_intranetService.isConnected.value) {
      await syncCatalogsIfNeeded();
      return await _offlineDbService.getPlagas() ?? [];
    }

    return [];
  }

  /// Obtener unidades de cultivo (casas)
  Future<List<dynamic>> getUnidadesCultivo() async {
    final local = await _offlineDbService.getCasas();
    if (local != null && local.isNotEmpty) {
      return local;
    }

    if (_intranetService.isConnected.value) {
      await syncCatalogsIfNeeded();
      return await _offlineDbService.getCasas() ?? [];
    }

    return [];
  }

  /// Obtener info de un lote específico
  Future<Map<String, dynamic>?> getLoteInfo(String codigo) async {
    // Primero buscar en cache local
    final cached = await _offlineDbService.getLoteInfo(codigo);
    if (cached != null) {
      return cached;
    }

    // Si no está en cache, buscar en lista de lotes
    final lotes = await getLotes();
    for (final lote in lotes) {
      if (lote['pmlt_codigo'] == codigo) {
        final loteMap = Map<String, dynamic>.from(lote);
        await _offlineDbService.saveLoteInfo(codigo, loteMap);
        return loteMap;
      }
    }

    return null;
  }

  /// Obtener niveles límites para una plaga
  Future<Map<String, dynamic>?> getNivelesPlaga(String plagaNombre) async {
    final niveles = await _offlineDbService.getNivelesLimites();
    if (niveles != null && niveles.containsKey(plagaNombre)) {
      return Map<String, dynamic>.from(niveles[plagaNombre]);
    }
    return null;
  }

  @override
  void dispose() {
    _intranetService.isConnected.removeListener(_onConnectionChanged);
    super.dispose();
  }
}
