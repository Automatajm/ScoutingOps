import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../core/config/flavor_config.dart';
import '../models/nivel_infestacion_model.dart';

class NivelInfestacionService {
  // Singleton pattern (siguiendo el patrón de LoteService y PlagaService)
  static final NivelInfestacionService _instance =
      NivelInfestacionService._internal();
  factory NivelInfestacionService() => _instance;
  NivelInfestacionService._internal();

  // ✅ Getter para obtener la URL desde la configuración centralizada
  String get nivelesInfestacionUrl => ApiConfig().nivelesInfestacionUrl;

  // Obtener niveles de infestación por plaga
  Future<List<NivelInfestacion>> getNivelesPorPlaga(int plagaId) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            "Obteniendo niveles para plaga ID: $plagaId (intento $attempt)");

        final response = await http
            .get(Uri.parse('$nivelesInfestacionUrl/plaga/$plagaId'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true && data['data'] != null) {
            final niveles = (data['data'] as List)
                .map((nivelJson) => NivelInfestacion.fromJson(nivelJson))
                .toList();
            debugPrint("Niveles cargados: ${niveles.length}");
            return niveles;
          } else {
            throw Exception('Error en la respuesta: ${data['message']}');
          }
        } else {
          throw Exception('Error al obtener niveles: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint("Error obteniendo niveles por plaga (intento $attempt): $e");

        if (attempt == maxRetries) {
          throw Exception('Error de conexión: $e');
        }

        // Reintento con espera exponencial
        debugPrint('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en getNivelesPorPlaga()');
  }

  // Obtener un nivel de infestación por secuencia
  Future<NivelInfestacion> getNivelById(int secuencia) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            "Obteniendo nivel con secuencia: $secuencia (intento $attempt)");

        final response = await http
            .get(Uri.parse('$nivelesInfestacionUrl/$secuencia'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true && data['data'] != null) {
            debugPrint("Nivel obtenido exitosamente");
            return NivelInfestacion.fromJson(data['data']);
          } else {
            throw Exception('Error en la respuesta: ${data['message']}');
          }
        } else {
          throw Exception('Error al obtener nivel: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint("Error obteniendo nivel por ID (intento $attempt): $e");

        if (attempt == maxRetries) {
          throw Exception('Error de conexión: $e');
        }

        // Reintento con espera exponencial
        debugPrint('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en getNivelById()');
  }

  // Crear un nuevo nivel de infestación
  Future<NivelInfestacion> crearNivelInfestacion(NivelInfestacion nivel) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            "Creando nivel de infestación: ${nivel.pmni_rango} (intento $attempt)");

        final response = await http
            .post(
              Uri.parse(nivelesInfestacionUrl),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(nivel.toJson()),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 201) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true && data['data'] != null) {
            debugPrint("Nivel de infestación creado exitosamente");
            return NivelInfestacion.fromJson(data['data']);
          } else {
            throw Exception('Error en la respuesta: ${data['message']}');
          }
        } else {
          final errorData = json.decode(response.body);
          throw Exception('Error al crear nivel: ${errorData['message']}');
        }
      } catch (e) {
        debugPrint("Error creando nivel de infestación (intento $attempt): $e");

        if (attempt == maxRetries) {
          throw Exception('Error de conexión: $e');
        }

        // Reintento con espera exponencial
        debugPrint('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en crearNivelInfestacion()');
  }

  // Actualizar un nivel de infestación existente
  Future<NivelInfestacion> actualizarNivelInfestacion(
      NivelInfestacion nivel) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    if (nivel.pmni_secuencia == null) {
      throw Exception('No se puede actualizar un nivel sin secuencia');
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            "Actualizando nivel secuencia: ${nivel.pmni_secuencia} (intento $attempt)");

        final response = await http
            .put(
              Uri.parse('$nivelesInfestacionUrl/${nivel.pmni_secuencia}'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(nivel.toJson()),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true && data['data'] != null) {
            debugPrint("Nivel de infestación actualizado exitosamente");
            return NivelInfestacion.fromJson(data['data']);
          } else {
            throw Exception('Error en la respuesta: ${data['message']}');
          }
        } else {
          final errorData = json.decode(response.body);
          throw Exception('Error al actualizar nivel: ${errorData['message']}');
        }
      } catch (e) {
        debugPrint(
            "Error actualizando nivel de infestación (intento $attempt): $e");

        if (attempt == maxRetries) {
          throw Exception('Error de conexión: $e');
        }

        // Reintento con espera exponencial
        debugPrint('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en actualizarNivelInfestacion()');
  }

  // Eliminar un nivel de infestación (baja lógica)
  Future<bool> eliminarNivelInfestacion(int secuencia) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint("Eliminando nivel secuencia: $secuencia (intento $attempt)");

        final response = await http
            .delete(Uri.parse('$nivelesInfestacionUrl/$secuencia'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true) {
            debugPrint("Nivel de infestación eliminado exitosamente");
            return true;
          } else {
            throw Exception('Error en la respuesta: ${data['message']}');
          }
        } else {
          final errorData = json.decode(response.body);
          throw Exception('Error al eliminar nivel: ${errorData['message']}');
        }
      } catch (e) {
        debugPrint(
            "Error eliminando nivel de infestación (intento $attempt): $e");

        if (attempt == maxRetries) {
          throw Exception('Error de conexión: $e');
        }

        // Reintento con espera exponencial
        debugPrint('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en eliminarNivelInfestacion()');
  }

  // Eliminar todos los niveles de una plaga
  Future<bool> eliminarNivelesPorPlaga(int plagaId) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            "Eliminando todos los niveles para plaga ID: $plagaId (intento $attempt)");

        final response = await http
            .delete(Uri.parse('$nivelesInfestacionUrl/plaga/$plagaId'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true) {
            debugPrint("Niveles de plaga eliminados exitosamente");
            return true;
          } else {
            throw Exception('Error en la respuesta: ${data['message']}');
          }
        } else {
          final errorData = json.decode(response.body);
          throw Exception('Error al eliminar niveles: ${errorData['message']}');
        }
      } catch (e) {
        debugPrint("Error eliminando niveles por plaga (intento $attempt): $e");

        if (attempt == maxRetries) {
          throw Exception('Error de conexión: $e');
        }

        // Reintento con espera exponencial
        debugPrint('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en eliminarNivelesPorPlaga()');
  }

  // Obtener límites generales para niveles de infestación
  Future<Map<String, dynamic>> getLimitesNiveles() async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint("Obteniendo límites de niveles (intento $attempt)");

        final response = await http
            .get(Uri.parse('$nivelesInfestacionUrl/limites'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true && data['data'] != null) {
            debugPrint("Límites de niveles obtenidos exitosamente");
            return data['data'];
          } else {
            throw Exception('Error en la respuesta: ${data['message']}');
          }
        } else {
          throw Exception('Error al obtener límites: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint(
            "Error obteniendo límites de niveles (intento $attempt): $e");

        if (attempt == maxRetries) {
          // Devolver valores por defecto en caso de error
          debugPrint("Usando límites por defecto como fallback");
          return {
            'lmsupniv1': 10,
            'lmsupniv2': 20,
            'lmsupniv3': 30,
          };
        }

        // Reintento con espera exponencial
        debugPrint('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    // Fallback por defecto
    return {
      'lmsupniv1': 10,
      'lmsupniv2': 20,
      'lmsupniv3': 30,
    };
  }
}
