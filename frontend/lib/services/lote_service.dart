import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../core/config/flavor_config.dart';
import '../models/lote_model.dart';

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

  // Getter para obtener la URL desde la configuración centralizada
  String get lotesUrl => ApiConfig().lotesUrl;
  String get variedadesUrl => '${ApiConfig().lotesUrl}/variedades/lista';

  // Método para obtener las variedades desde la API - MODIFICADO para manejar correctamente el código
  Future<Map<int, Map<String, String>>> getVariedades() async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            "Solicitando variedades a: $variedadesUrl (intento $attempt)");

        // Tiempo de espera reducido ya que usamos stored procedure
        final response = await http
            .get(Uri.parse(variedadesUrl))
            .timeout(const Duration(seconds: 10));

        debugPrint("Respuesta de variedades: Status ${response.statusCode}");

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true && data['data'] != null) {
            final List<dynamic> variedadesData = data['data'];

            // Convertir la lista a un mapa de id -> {descripcion, codigo}
            final Map<int, Map<String, String>> variedadesMap = {};

            for (var variedad in variedadesData) {
              // Extraer valores usando las claves correctas
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

            debugPrint("Variedades cargadas: ${variedadesMap.length}");
            return variedadesMap;
          } else {
            debugPrint("Error en respuesta: ${data['message']}");
            if (attempt == maxRetries) {
              return _getVariedadesPredefinidas();
            }
          }
        } else {
          debugPrint("Error de API: ${response.statusCode}, ${response.body}");
          if (attempt == maxRetries) {
            return _getVariedadesPredefinidas();
          }
        }

        // Reintento con espera exponencial
        print(
            'Reintentando obtener variedades en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } catch (e) {
        debugPrint("Excepción obteniendo variedades (intento $attempt): $e");

        if (attempt == maxRetries) {
          return _getVariedadesPredefinidas();
        }

        // Reintento con espera exponencial
        print(
            'Reintentando obtener variedades en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    return _getVariedadesPredefinidas();
  }

  // Método para obtener variedades predeterminadas en caso de error - MODIFICADO
  Map<int, Map<String, String>> _getVariedadesPredefinidas() {
    debugPrint("Usando variedades predefinidas como fallback");
    return {
      1: {
        'descripcion': 'Variedad Genérica',
        'codigo': '1',
      },
    };
  }

  // Obtener todos los lotes con filtros opcionales - MODIFICADO para usar código de variedad
  Future<List<Lote>> getLotes({
    String? codigoVariedad, // Cambiado de variedad a codigoVariedad
    String? estatus,
    String? busqueda,
  }) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // Construir parámetros de consulta
        final queryParams = <String, String>{};
        if (codigoVariedad != null && codigoVariedad != 'Todos') {
          queryParams['codigo_variedad'] =
              codigoVariedad; // Cambiado de variedad a codigo_variedad
        }
        if (estatus != null && estatus != 'Todos') {
          queryParams['estatus'] = estatus;
        }
        if (busqueda != null && busqueda.isNotEmpty) {
          queryParams['busqueda'] = busqueda;
        }

        // Crear URI con parámetros
        final uri = Uri.parse(lotesUrl).replace(queryParameters: queryParams);

        debugPrint("Solicitando lotes a: $uri (intento $attempt)");

        // Tiempo de espera reducido ya que usamos stored procedure
        final response =
            await http.get(uri).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true && data['data'] != null) {
            final lotes = (data['data'] as List)
                .map((loteJson) => Lote.fromJson(loteJson))
                .toList();
            debugPrint("Lotes cargados: ${lotes.length}");
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
          throw Exception('Error de conexión: $e');
        }

        // Reintento con espera exponencial
        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en getLotes()');
  }

  // Obtener un lote por ID usando stored procedure
  Future<Lote> getLoteById(int id) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint("Obteniendo lote con ID: $id (intento $attempt)");

        // Tiempo de espera reducido ya que usamos stored procedure
        final response = await http
            .get(Uri.parse('$lotesUrl/$id'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true && data['data'] != null) {
            debugPrint("Lote obtenido exitosamente");
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
          throw Exception('Error de conexión: $e');
        }

        // Reintento con espera exponencial
        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en getLoteById()');
  }

  // Crear un nuevo lote usando stored procedure
  Future<Lote> crearLote(Lote lote) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint("Creando lote: ${lote.pmlt_codigo} (intento $attempt)");

        // Tiempo de espera reducido ya que usamos stored procedure
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
            // El SP devuelve el lote completo como JSON
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

        // Reintento con espera exponencial
        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en crearLote()');
  }

  // Actualizar un lote existente usando stored procedure
  Future<Lote> actualizarLote(Lote lote) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    if (lote.pmlt_secuencia == null) {
      throw Exception('No se puede actualizar un lote sin ID');
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            "Actualizando lote ID: ${lote.pmlt_secuencia} (intento $attempt)");

        // Tiempo de espera reducido ya que usamos stored procedure
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
            // El SP devuelve el lote actualizado como JSON
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

        // Reintento con espera exponencial
        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en actualizarLote()');
  }

  // Eliminar un lote (baja lógica) usando stored procedure
  Future<bool> eliminarLote(int id) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint("Eliminando lote ID: $id (intento $attempt)");

        // Tiempo de espera reducido ya que usamos stored procedure
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

        // Reintento con espera exponencial
        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en eliminarLote()');
  }

  // Método para importar lotes (usado por la pantalla de importación)
  Future<ImportResult> importarLotes(List<Lote> lotes) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            "Importando lotes (intento $attempt): ${lotes.length} lotes");

        // Intentar usar el endpoint batch primero
        final batchResult = await importarLotesBatch(lotes);

        return ImportResult(
          creados: batchResult,
          actualizados: 0,
          ignorados: lotes.length - batchResult,
        );
      } catch (e) {
        debugPrint("Error importando lotes (intento $attempt): $e");

        if (attempt == maxRetries) {
          // Implementación alternativa si falla la importación batch
          debugPrint("Intentando importación uno por uno...");

          // Contadores para el resultado
          int creados = 0;
          int ignorados = 0;

          // Procesar lotes uno por uno
          for (var lote in lotes) {
            try {
              // Verificar si ya existe un lote con ese código
              final existentes = await getLotes(busqueda: lote.pmlt_codigo);

              bool existeLote = existentes.any((l) =>
                  l.pmlt_codigo?.toLowerCase() ==
                  lote.pmlt_codigo?.toLowerCase());

              if (existeLote) {
                // Si ya existe, ignorarlo
                ignorados++;
                continue;
              }

              // Crear el lote
              await crearLote(lote);
              creados++;
            } catch (e) {
              // Contar lotes que no se pudieron procesar
              ignorados++;
              debugPrint('Error al procesar lote ${lote.pmlt_codigo}: $e');
            }
          }

          // Devolver resultado
          return ImportResult(
            creados: creados,
            actualizados: 0,
            ignorados: ignorados,
          );
        }

        // Reintento con espera exponencial
        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en importarLotes()');
  }

  // Método para importar lotes en batch (múltiples lotes a la vez) usando stored procedure
  Future<int> importarLotesBatch(List<Lote> lotes) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            "Importando lotes en batch (intento $attempt): ${lotes.length} lotes");

        // Tiempo de espera aumentado para operaciones batch
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
            // Devuelve el número de lotes creados
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

        // Reintento con espera exponencial
        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en importarLotesBatch()');
  }
}
