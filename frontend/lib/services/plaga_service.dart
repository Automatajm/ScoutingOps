import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../core/config/flavor_config.dart';
import '../models/plaga_model.dart';

class PlagaService {
  // Singleton pattern (igual que LoteService)
  static final PlagaService _instance = PlagaService._internal();
  factory PlagaService() => _instance;
  PlagaService._internal();

  // ✅ Getter para obtener la URL desde la configuración centralizada
  String get plagasUrl => ApiConfig().plagasUrl;
  String get tiposUrl => '${ApiConfig().plagasUrl}/tipos';

  // Método para obtener los tipos de plagas desde la API
  Future<Map<int, String>> getTiposPlagas() async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            "Solicitando tipos de plaga a: $tiposUrl (intento $attempt)");

        final response = await http
            .get(Uri.parse(tiposUrl))
            .timeout(const Duration(seconds: 10));

        debugPrint("Respuesta de tipos: Status ${response.statusCode}");

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true && data['data'] != null) {
            final List<dynamic> tiposData = data['data'];

            // Convertir la lista a un mapa de id -> descripción
            final Map<int, String> tiposMap = {};
            for (var tipo in tiposData) {
              tiposMap[tipo['id']] = tipo['descripcion'];
            }

            debugPrint("Tipos cargados: ${tiposMap.length}");
            return tiposMap;
          } else {
            debugPrint("Error en respuesta: ${data['message']}");
            if (attempt == maxRetries) {
              return _getTiposPredefinidos();
            }
          }
        } else {
          debugPrint("Error de API: ${response.statusCode}, ${response.body}");
          if (attempt == maxRetries) {
            return _getTiposPredefinidos();
          }
        }

        // Reintento con espera exponencial
        debugPrint(
            'Reintentando obtener tipos en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } catch (e) {
        debugPrint("Excepción obteniendo tipos (intento $attempt): $e");

        if (attempt == maxRetries) {
          return _getTiposPredefinidos();
        }

        // Reintento con espera exponencial
        debugPrint(
            'Reintentando obtener tipos en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    return _getTiposPredefinidos();
  }

  // Método para obtener tipos predeterminados en caso de error
  Map<int, String> _getTiposPredefinidos() {
    debugPrint("Usando tipos predefinidos como fallback");
    return {
      1: 'Insecto (plaga)',
      2: 'Bacteria (patogeno)',
      3: 'Nemato (patogeno)',
      4: 'Hongo (patogeno)',
      5: 'Acaro (Plaga)',
      6: 'Virus (patogeno)'
    };
  }

  // Obtener todas las plagas con filtros opcionales
  Future<List<Plaga>> getPlagas({
    String? tipo,
    String? estatus,
    String? busqueda,
  }) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // Construir parámetros de consulta
        final queryParams = <String, String>{};
        if (tipo != null && tipo != 'Todos') queryParams['tipo'] = tipo;
        if (estatus != null && estatus != 'Todos')
          queryParams['estatus'] = estatus;
        if (busqueda != null && busqueda.isNotEmpty)
          queryParams['busqueda'] = busqueda;

        // Crear URI con parámetros usando la URL dinámica
        final uri = Uri.parse(plagasUrl).replace(queryParameters: queryParams);

        debugPrint("Solicitando plagas a: $uri (intento $attempt)");

        final response =
            await http.get(uri).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true && data['data'] != null) {
            final plagas = (data['data'] as List)
                .map((plagaJson) => Plaga.fromJson(plagaJson))
                .toList();
            debugPrint("Plagas cargadas: ${plagas.length}");
            return plagas;
          } else {
            throw Exception('Error en la respuesta: ${data['message']}');
          }
        } else {
          throw Exception('Error al obtener plagas: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint("Error obteniendo plagas (intento $attempt): $e");

        if (attempt == maxRetries) {
          throw Exception('Error de conexión: $e');
        }

        // Reintento con espera exponencial
        debugPrint('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en getPlagas()');
  }

  // Obtener una plaga por ID
  Future<Plaga> getPlagaById(int id) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint("Obteniendo plaga con ID: $id (intento $attempt)");

        final response = await http
            .get(Uri.parse('$plagasUrl/$id'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true && data['data'] != null) {
            debugPrint("Plaga obtenida exitosamente");
            return Plaga.fromJson(data['data']);
          } else {
            throw Exception('Error en la respuesta: ${data['message']}');
          }
        } else {
          throw Exception('Error al obtener plaga: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint("Error obteniendo plaga por ID (intento $attempt): $e");

        if (attempt == maxRetries) {
          throw Exception('Error de conexión: $e');
        }

        // Reintento con espera exponencial
        debugPrint('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en getPlagaById()');
  }

  // Crear una nueva plaga
  Future<Plaga> crearPlaga(Plaga plaga) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            "Creando plaga: ${plaga.pmpl_nombrecomun} (intento $attempt)");

        final response = await http
            .post(
              Uri.parse(plagasUrl),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(plaga.toJson()),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 201) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true && data['data'] != null) {
            debugPrint("Plaga creada exitosamente");
            return Plaga.fromJson(data['data']);
          } else {
            throw Exception('Error en la respuesta: ${data['message']}');
          }
        } else {
          final errorData = json.decode(response.body);
          throw Exception('Error al crear plaga: ${errorData['message']}');
        }
      } catch (e) {
        debugPrint("Error creando plaga (intento $attempt): $e");

        if (attempt == maxRetries) {
          throw Exception('Error de conexión: $e');
        }

        // Reintento con espera exponencial
        debugPrint('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en crearPlaga()');
  }

  // Actualizar una plaga existente
  Future<Plaga> actualizarPlaga(Plaga plaga) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    if (plaga.pmpl_id == null) {
      throw Exception('No se puede actualizar una plaga sin ID');
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            "Actualizando plaga ID: ${plaga.pmpl_id} (intento $attempt)");

        final response = await http
            .put(
              Uri.parse('$plagasUrl/${plaga.pmpl_id}'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(plaga.toJson()),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true && data['data'] != null) {
            debugPrint("Plaga actualizada exitosamente");
            return Plaga.fromJson(data['data']);
          } else {
            throw Exception('Error en la respuesta: ${data['message']}');
          }
        } else {
          final errorData = json.decode(response.body);
          throw Exception('Error al actualizar plaga: ${errorData['message']}');
        }
      } catch (e) {
        debugPrint("Error actualizando plaga (intento $attempt): $e");

        if (attempt == maxRetries) {
          throw Exception('Error de conexión: $e');
        }

        // Reintento con espera exponencial
        debugPrint('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en actualizarPlaga()');
  }

  // Eliminar una plaga (baja lógica)
  Future<bool> eliminarPlaga(int id) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint("Eliminando plaga ID: $id (intento $attempt)");

        final response = await http
            .delete(Uri.parse('$plagasUrl/$id'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true) {
            debugPrint("Plaga eliminada exitosamente");
            return true;
          } else {
            throw Exception('Error en la respuesta: ${data['message']}');
          }
        } else {
          final errorData = json.decode(response.body);
          throw Exception('Error al eliminar plaga: ${errorData['message']}');
        }
      } catch (e) {
        debugPrint("Error eliminando plaga (intento $attempt): $e");

        if (attempt == maxRetries) {
          throw Exception('Error de conexión: $e');
        }

        // Reintento con espera exponencial
        debugPrint('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en eliminarPlaga()');
  }
}
