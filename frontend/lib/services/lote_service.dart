import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../core/config/flavor_config.dart';
import '../models/lote_model.dart';
import '../data/database/app_database.dart';

// Clase para el resultado de la importación
class ImportResult {
  final int creados;
  final int actualizados;
  final int ignorados;

  ImportResult({
    required this.creados,
    required this.actualizados,
    required this.ignorados,
  });
}

class LoteService {
  // Singleton pattern
  static final LoteService _instance = LoteService._internal();
  factory LoteService() => _instance;
  LoteService._internal();

  // Referencia a la base de datos SQLite (se inyecta después de inicializar)
  AppDatabase? _database;

  // Setter para inyectar la base de datos
  void setDatabase(AppDatabase db) {
    _database = db;
    debugPrint('📦 LoteService: Base de datos SQLite configurada');
  }

  // Getter para obtener la URL desde la configuración centralizada
  String get lotesUrl => ApiConfig().lotesUrl;
  String get variedadesUrl => '${ApiConfig().lotesUrl}/variedades/lista';

  // ============================================================
  // MÉTODOS CON SOPORTE OFFLINE
  // ============================================================

  /// Obtener variedades - Primero intenta SQLite, luego API
  Future<Map<int, Map<String, String>>> getVariedades() async {
    // 1. Intentar obtener de SQLite primero (respuesta instantánea)
    final localData = await _getVariedadesFromSQLite();
    if (localData.isNotEmpty) {
      debugPrint('📦 Variedades cargadas desde SQLite: ${localData.length}');

      // Intentar actualizar en background si hay conexión
      _refreshVariedadesInBackground();

      return localData;
    }

    // 2. Si no hay datos locales, intentar API
    debugPrint('🌐 No hay variedades locales, consultando API...');
    return await _getVariedadesFromAPI();
  }

  /// Obtener variedades desde SQLite
  Future<Map<int, Map<String, String>>> _getVariedadesFromSQLite() async {
    if (_database == null) {
      debugPrint('⚠️ Base de datos no configurada en LoteService');
      return {};
    }

    try {
      // getCatalogo ahora retorna Map<String, dynamic>? en lugar de CatalogosData?
      final catalogoMap = await _database!.getCatalogo('variedades');
      if (catalogoMap != null) {
        final dataString = catalogoMap['data'] as String?;
        if (dataString != null) {
          final List<dynamic> variedadesData = json.decode(dataString);
          final Map<int, Map<String, String>> variedadesMap = {};

          for (var variedad in variedadesData) {
            final id = variedad['id'];
            final descripcion = variedad['descripcion']?.toString() ?? '';
            final codigo = variedad['codigo']?.toString() ?? '';

            if (id != null) {
              variedadesMap[id is int ? id : int.tryParse(id.toString()) ?? 0] =
                  {
                'descripcion': descripcion,
                'codigo': codigo,
              };
            }
          }

          return variedadesMap;
        }
      }
    } catch (e) {
      debugPrint('❌ Error leyendo variedades de SQLite: $e');
    }

    return {};
  }

  /// Actualizar variedades en background
  void _refreshVariedadesInBackground() {
    Future.microtask(() async {
      try {
        await _getVariedadesFromAPI();
      } catch (e) {
        // Silencioso - no importa si falla el refresh
      }
    });
  }

  /// Obtener variedades desde API (método original)
  Future<Map<int, Map<String, String>>> _getVariedadesFromAPI() async {
    int maxRetries = 2;
    int retryDelay = 1000;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            "Solicitando variedades a: $variedadesUrl (intento $attempt)");

        final response = await http
            .get(Uri.parse(variedadesUrl))
            .timeout(const Duration(seconds: 10));

        debugPrint("Respuesta de variedades: Status ${response.statusCode}");

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true && data['data'] != null) {
            final List<dynamic> variedadesData = data['data'];
            final Map<int, Map<String, String>> variedadesMap = {};

            for (var variedad in variedadesData) {
              final id = variedad['id'];
              final descripcion = variedad['descripcion'] as String;
              final codigo = variedad['codigo'] as String;

              if (id != null && descripcion != null && codigo != null) {
                variedadesMap[id] = {
                  'descripcion': descripcion,
                  'codigo': codigo,
                };
              }
            }

            debugPrint(
                "Variedades cargadas desde API: ${variedadesMap.length}");
            return variedadesMap;
          }
        }

        if (attempt == maxRetries) {
          return _getVariedadesPredefinidas();
        }

        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } catch (e) {
        debugPrint("Excepción obteniendo variedades (intento $attempt): $e");

        if (attempt == maxRetries) {
          // Último intento: usar datos locales o predefinidos
          final localData = await _getVariedadesFromSQLite();
          if (localData.isNotEmpty) {
            return localData;
          }
          return _getVariedadesPredefinidas();
        }

        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    return _getVariedadesPredefinidas();
  }

  Map<int, Map<String, String>> _getVariedadesPredefinidas() {
    debugPrint("Usando variedades predefinidas como fallback");
    return {
      1: {
        'descripcion': 'Variedad Genérica',
        'codigo': '1',
      },
    };
  }

  // ============================================================
  // LOTES - CON SOPORTE OFFLINE
  // ============================================================

  /// Obtener todos los lotes - Primero SQLite, luego API
  Future<List<Lote>> getLotes({
    String? codigoVariedad,
    String? estatus,
    String? busqueda,
  }) async {
    // 1. Intentar obtener de SQLite primero
    final localLotes = await _getLotesFromSQLite(
      codigoVariedad: codigoVariedad,
      estatus: estatus,
      busqueda: busqueda,
    );

    if (localLotes.isNotEmpty) {
      debugPrint('📦 Lotes cargados desde SQLite: ${localLotes.length}');

      // Intentar actualizar en background
      _refreshLotesInBackground();

      return localLotes;
    }

    // 2. Si no hay datos locales, intentar API
    debugPrint('🌐 No hay lotes locales, consultando API...');
    return await _getLotesFromAPI(
      codigoVariedad: codigoVariedad,
      estatus: estatus,
      busqueda: busqueda,
    );
  }

  /// Obtener lotes desde SQLite
  Future<List<Lote>> _getLotesFromSQLite({
    String? codigoVariedad,
    String? estatus,
    String? busqueda,
  }) async {
    if (_database == null) {
      debugPrint('⚠️ Base de datos no configurada en LoteService');
      return [];
    }

    try {
      // getCatalogo ahora retorna Map<String, dynamic>? en lugar de CatalogosData?
      final catalogoMap = await _database!.getCatalogo('lotes');
      if (catalogoMap != null) {
        final dataString = catalogoMap['data'] as String?;
        if (dataString != null) {
          final List<dynamic> lotesData = json.decode(dataString);
          List<Lote> lotes =
              lotesData.map((loteJson) => Lote.fromJson(loteJson)).toList();

          // Aplicar filtros localmente
          if (codigoVariedad != null && codigoVariedad != 'Todos') {
            lotes = lotes
                .where((l) => l.pmlt_variedad?.toString() == codigoVariedad)
                .toList();
          }

          if (estatus != null && estatus != 'Todos') {
            lotes = lotes
                .where((l) => l.pmlt_estatus?.toString() == estatus)
                .toList();
          }

          if (busqueda != null && busqueda.isNotEmpty) {
            final searchLower = busqueda.toLowerCase();
            lotes = lotes
                .where((l) =>
                    (l.pmlt_codigo?.toLowerCase().contains(searchLower) ??
                        false) ||
                    (l.pmlt_codigo?.toLowerCase().contains(searchLower) ??
                        false))
                .toList();
          }

          return lotes;
        }
      }
    } catch (e) {
      debugPrint('❌ Error leyendo lotes de SQLite: $e');
    }

    return [];
  }

  /// Actualizar lotes en background
  void _refreshLotesInBackground() {
    Future.microtask(() async {
      try {
        await _getLotesFromAPI();
      } catch (e) {
        // Silencioso
      }
    });
  }

  /// Obtener lotes desde API
  Future<List<Lote>> _getLotesFromAPI({
    String? codigoVariedad,
    String? estatus,
    String? busqueda,
  }) async {
    int maxRetries = 2;
    int retryDelay = 1000;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final queryParams = <String, String>{};
        if (codigoVariedad != null && codigoVariedad != 'Todos') {
          queryParams['codigo_variedad'] = codigoVariedad;
        }
        if (estatus != null && estatus != 'Todos') {
          queryParams['estatus'] = estatus;
        }
        if (busqueda != null && busqueda.isNotEmpty) {
          queryParams['busqueda'] = busqueda;
        }

        final uri = Uri.parse(lotesUrl).replace(queryParameters: queryParams);
        debugPrint("Solicitando lotes a: $uri (intento $attempt)");

        final response =
            await http.get(uri).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true && data['data'] != null) {
            final lotes = (data['data'] as List)
                .map((loteJson) => Lote.fromJson(loteJson))
                .toList();
            debugPrint("Lotes cargados desde API: ${lotes.length}");
            return lotes;
          } else {
            throw Exception('Error en la respuesta: ${data['message']}');
          }
        } else {
          throw Exception('Error al obtener lotes: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint("Error obteniendo lotes (intento $attempt): $e");

        if (attempt == maxRetries) {
          // Último intento: usar datos locales
          final localLotes = await _getLotesFromSQLite(
            codigoVariedad: codigoVariedad,
            estatus: estatus,
            busqueda: busqueda,
          );

          if (localLotes.isNotEmpty) {
            debugPrint('📦 Usando lotes de SQLite como fallback');
            return localLotes;
          }

          throw Exception('Error de conexión y sin datos locales: $e');
        }

        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en getLotes()');
  }

  // ============================================================
  // OBTENER LOTE POR ID - CON SOPORTE OFFLINE
  // ============================================================

  /// Obtener un lote por ID - Primero SQLite, luego API
  Future<Lote> getLoteById(int id) async {
    // 1. Buscar en SQLite primero
    final localLote = await _getLoteByIdFromSQLite(id);
    if (localLote != null) {
      debugPrint('📦 Lote $id cargado desde SQLite');
      return localLote;
    }

    // 2. Si no está en SQLite, buscar en API
    debugPrint('🌐 Lote $id no encontrado localmente, consultando API...');
    return await _getLoteByIdFromAPI(id);
  }

  /// Buscar lote por ID en SQLite
  Future<Lote?> _getLoteByIdFromSQLite(int id) async {
    if (_database == null) return null;

    try {
      // Primero intentar con catálogo específico por código
      final catalogoEspecifico =
          await _database!.getCatalogo('lote_info', clave: id.toString());
      if (catalogoEspecifico != null) {
        final dataString = catalogoEspecifico['data'] as String?;
        if (dataString != null) {
          return Lote.fromJson(json.decode(dataString));
        }
      }

      // Si no, buscar en el catálogo general de lotes
      final catalogoMap = await _database!.getCatalogo('lotes');
      if (catalogoMap != null) {
        final dataString = catalogoMap['data'] as String?;
        if (dataString != null) {
          final List<dynamic> lotesData = json.decode(dataString);
          for (var loteJson in lotesData) {
            // Buscar por secuencia o id
            if (loteJson['pmlt_secuencia'] == id || loteJson['id'] == id) {
              return Lote.fromJson(loteJson);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error buscando lote $id en SQLite: $e');
    }

    return null;
  }

  /// Obtener lote por ID desde API
  Future<Lote> _getLoteByIdFromAPI(int id) async {
    int maxRetries = 2;
    int retryDelay = 1000;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint("Obteniendo lote con ID: $id (intento $attempt)");

        final response = await http
            .get(Uri.parse('$lotesUrl/$id'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true && data['data'] != null) {
            debugPrint("Lote obtenido exitosamente desde API");
            return Lote.fromJson(data['data']);
          } else {
            throw Exception('Error en la respuesta: ${data['message']}');
          }
        } else {
          throw Exception('Error al obtener lote: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint("Error obteniendo lote por ID (intento $attempt): $e");

        if (attempt == maxRetries) {
          // Último intento: buscar en SQLite
          final localLote = await _getLoteByIdFromSQLite(id);
          if (localLote != null) {
            return localLote;
          }
          throw Exception('Lote no encontrado y sin conexión: $e');
        }

        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en getLoteById()');
  }

  // ============================================================
  // MÉTODOS DE ESCRITURA (requieren conexión)
  // ============================================================

  Future<Lote> crearLote(Lote lote) async {
    int maxRetries = 2;
    int retryDelay = 1000;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint("Creando lote: ${lote.pmlt_codigo} (intento $attempt)");

        final response = await http
            .post(
              Uri.parse(lotesUrl),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(lote.toJson()),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 201) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true && data['data'] != null) {
            debugPrint("Lote creado exitosamente");
            return Lote.fromJson(data['data']);
          } else {
            throw Exception('Error en la respuesta: ${data['message']}');
          }
        } else {
          final errorData = json.decode(response.body);
          throw Exception('Error al crear lote: ${errorData['message']}');
        }
      } catch (e) {
        debugPrint("Error creando lote (intento $attempt): $e");

        if (attempt == maxRetries) {
          throw Exception('Error de conexión: $e');
        }

        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en crearLote()');
  }

  Future<Lote> actualizarLote(Lote lote) async {
    int maxRetries = 2;
    int retryDelay = 1000;

    if (lote.pmlt_secuencia == null) {
      throw Exception('No se puede actualizar un lote sin ID');
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            "Actualizando lote ID: ${lote.pmlt_secuencia} (intento $attempt)");

        final response = await http
            .put(
              Uri.parse('$lotesUrl/${lote.pmlt_secuencia}'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(lote.toJson()),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true && data['data'] != null) {
            debugPrint("Lote actualizado exitosamente");
            return Lote.fromJson(data['data']);
          } else {
            throw Exception('Error en la respuesta: ${data['message']}');
          }
        } else {
          final errorData = json.decode(response.body);
          throw Exception('Error al actualizar lote: ${errorData['message']}');
        }
      } catch (e) {
        debugPrint("Error actualizando lote (intento $attempt): $e");

        if (attempt == maxRetries) {
          throw Exception('Error de conexión: $e');
        }

        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en actualizarLote()');
  }

  Future<bool> eliminarLote(int id) async {
    int maxRetries = 2;
    int retryDelay = 1000;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint("Eliminando lote ID: $id (intento $attempt)");

        final response = await http
            .delete(Uri.parse('$lotesUrl/$id'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true) {
            debugPrint("Lote eliminado exitosamente");
            return true;
          } else {
            throw Exception('Error en la respuesta: ${data['message']}');
          }
        } else {
          final errorData = json.decode(response.body);
          throw Exception('Error al eliminar lote: ${errorData['message']}');
        }
      } catch (e) {
        debugPrint("Error eliminando lote (intento $attempt): $e");

        if (attempt == maxRetries) {
          throw Exception('Error de conexión: $e');
        }

        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en eliminarLote()');
  }

  Future<ImportResult> importarLotes(List<Lote> lotes) async {
    int maxRetries = 2;
    int retryDelay = 1000;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            "Importando lotes (intento $attempt): ${lotes.length} lotes");

        final batchResult = await importarLotesBatch(lotes);

        return ImportResult(
          creados: batchResult,
          actualizados: 0,
          ignorados: lotes.length - batchResult,
        );
      } catch (e) {
        debugPrint("Error importando lotes (intento $attempt): $e");

        if (attempt == maxRetries) {
          debugPrint("Intentando importación uno por uno...");

          int creados = 0;
          int ignorados = 0;

          for (var lote in lotes) {
            try {
              final existentes = await getLotes(busqueda: lote.pmlt_codigo);
              bool existeLote = existentes.any((l) =>
                  l.pmlt_codigo?.toLowerCase() ==
                  lote.pmlt_codigo?.toLowerCase());

              if (existeLote) {
                ignorados++;
                continue;
              }

              await crearLote(lote);
              creados++;
            } catch (e) {
              ignorados++;
              debugPrint('Error al procesar lote ${lote.pmlt_codigo}: $e');
            }
          }

          return ImportResult(
            creados: creados,
            actualizados: 0,
            ignorados: ignorados,
          );
        }

        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en importarLotes()');
  }

  Future<int> importarLotesBatch(List<Lote> lotes) async {
    int maxRetries = 2;
    int retryDelay = 1000;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            "Importando lotes en batch (intento $attempt): ${lotes.length} lotes");

        final response = await http
            .post(
              Uri.parse('$lotesUrl/batch'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'lotes': lotes.map((lote) => lote.toJson()).toList(),
              }),
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 201) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true) {
            debugPrint(
                "Importación batch exitosa: ${data['count']} lotes creados");
            return data['count'] ?? 0;
          } else {
            throw Exception('Error en la respuesta: ${data['message']}');
          }
        } else {
          final errorData = json.decode(response.body);
          throw Exception('Error al importar lotes: ${errorData['message']}');
        }
      } catch (e) {
        debugPrint("Error en importación batch (intento $attempt): $e");

        if (attempt == maxRetries) {
          throw Exception('Error en importación batch: $e');
        }

        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en importarLotesBatch()');
  }
}
