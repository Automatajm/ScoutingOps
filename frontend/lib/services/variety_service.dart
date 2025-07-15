import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/variety_model.dart';
import '../core/config/flavor_config.dart'; // Importación de configuración centralizada

class VarietyService {
  // Singleton para asegurar una única instancia
  static final VarietyService _instance = VarietyService._internal();
  factory VarietyService() => _instance;
  VarietyService._internal();

  // Getter para URL de variedades usando ApiConfig
  String get variedadesUrl => ApiConfig().variedadesUrl;

  // Obtener todas las variedades usando stored procedure
  Future<List<Variety>> getVarieties(
      {String? busqueda, String? estatus}) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // Construir parámetros de consulta
        final Map<String, String> queryParams = {};
        if (busqueda != null && busqueda.isNotEmpty) {
          queryParams['busqueda'] = busqueda;
        }
        if (estatus != null && estatus.isNotEmpty) {
          queryParams['estatus'] = estatus;
        }

        final uri =
            Uri.parse(variedadesUrl).replace(queryParameters: queryParams);

        print('Obteniendo variedades desde: $uri (intento $attempt)');

        // Tiempo de espera reducido ya que usamos stored procedure
        final response =
            await http.get(uri).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          print('Variedades obtenidas exitosamente: ${data.length}');
          return data.map((json) => Variety.fromJson(json)).toList();
        } else {
          print('Error ${response.statusCode}: ${response.body}');
          throw Exception('Error al cargar variedades: ${response.statusCode}');
        }
      } on SocketException {
        print('Error de conexión (intento $attempt)');

        if (attempt == maxRetries) {
          throw Exception(
              'Error de conexión. Verifique su conexión a internet y la configuración del servidor.');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on TimeoutException {
        print('Tiempo de espera agotado (intento $attempt)');

        if (attempt == maxRetries) {
          throw Exception(
              'Tiempo de espera agotado. El servidor está tardando demasiado en responder.');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on FormatException {
        print('Error en formato de datos (intento $attempt)');

        if (attempt == maxRetries) {
          throw Exception(
              'Error en el formato de datos recibidos del servidor.');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } catch (e) {
        print('Error no manejado (intento $attempt): $e');

        if (attempt == maxRetries) {
          throw Exception('Error inesperado: $e');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    // Este código no debería alcanzarse debido al manejo de excepciones
    throw Exception('Error inesperado en getVarieties()');
  }

  // Obtener una variedad por ID usando stored procedure
  Future<Variety> getVarietyById(int id) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Obteniendo variedad con ID: $id (intento $attempt)');

        // Tiempo de espera reducido ya que usamos stored procedure
        final response = await http
            .get(Uri.parse('$variedadesUrl/$id'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final dynamic data = json.decode(response.body);
          print('Variedad obtenida exitosamente');
          return Variety.fromJson(data);
        } else {
          print('Error ${response.statusCode}: ${response.body}');
          throw Exception(
              'Error al cargar la variedad: ${response.statusCode}');
        }
      } on SocketException {
        print('Error de conexión (intento $attempt)');

        if (attempt == maxRetries) {
          throw Exception(
              'Error de conexión. Verifique su conexión a internet y la configuración del servidor.');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on TimeoutException {
        print('Tiempo de espera agotado (intento $attempt)');

        if (attempt == maxRetries) {
          throw Exception(
              'Tiempo de espera agotado. El servidor está tardando demasiado en responder.');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on FormatException {
        print('Error en formato de datos (intento $attempt)');

        if (attempt == maxRetries) {
          throw Exception(
              'Error en el formato de datos recibidos del servidor.');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } catch (e) {
        print('Error no manejado (intento $attempt): $e');

        if (attempt == maxRetries) {
          throw Exception('Error inesperado: $e');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    // Este código no debería alcanzarse debido al manejo de excepciones
    throw Exception('Error inesperado en getVarietyById()');
  }

  // Crear una nueva variedad usando stored procedure
  Future<int> createVariety(Variety variety) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Creando nueva variedad: ${variety.codigo} (intento $attempt)');

        final response = await http
            .post(
              Uri.parse(variedadesUrl),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'codigo': variety.codigo,
                'descripcion': variety.descripcion,
                'responsable': variety.responsable,
                'estatus': variety.estatus,
                'creadoPor': variety.creadoPor,
              }),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 201) {
          final int variedadId = json.decode(response.body);
          print('Variedad creada exitosamente con ID: $variedadId');
          return variedadId;
        } else {
          final Map<String, dynamic> errorData = json.decode(response.body);
          print('Error al crear variedad: ${errorData['message']}');
          throw Exception('Error al crear variedad: ${errorData['message']}');
        }
      } on SocketException {
        print('Error de conexión (intento $attempt)');

        if (attempt == maxRetries) {
          throw Exception(
              'Error de conexión. Verifique su conexión a internet y la configuración del servidor.');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on TimeoutException {
        print('Tiempo de espera agotado (intento $attempt)');

        if (attempt == maxRetries) {
          throw Exception(
              'Tiempo de espera agotado. El servidor está tardando demasiado en responder.');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on FormatException {
        print('Error en formato de datos (intento $attempt)');

        if (attempt == maxRetries) {
          throw Exception(
              'Error en el formato de datos recibidos del servidor.');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } catch (e) {
        print('Error no manejado (intento $attempt): $e');

        if (attempt == maxRetries) {
          throw Exception('Error inesperado: $e');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    // Este código no debería alcanzarse debido al manejo de excepciones
    throw Exception('Error inesperado en createVariety()');
  }

  // Actualizar una variedad existente usando stored procedure
  Future<bool> updateVariety(Variety variety) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Actualizando variedad ID: ${variety.id} (intento $attempt)');

        final response = await http
            .put(
              Uri.parse('$variedadesUrl/${variety.id}'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'codigo': variety.codigo,
                'descripcion': variety.descripcion,
                'responsable': variety.responsable,
                'estatus': variety.estatus,
                'modificadoPor': variety.modificadoPor,
              }),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final bool success = json.decode(response.body);
          print('Variedad actualizada exitosamente');
          return success;
        } else {
          final Map<String, dynamic> errorData = json.decode(response.body);
          print('Error al actualizar variedad: ${errorData['message']}');
          throw Exception(
              'Error al actualizar variedad: ${errorData['message']}');
        }
      } on SocketException {
        print('Error de conexión (intento $attempt)');

        if (attempt == maxRetries) {
          throw Exception(
              'Error de conexión. Verifique su conexión a internet y la configuración del servidor.');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on TimeoutException {
        print('Tiempo de espera agotado (intento $attempt)');

        if (attempt == maxRetries) {
          throw Exception(
              'Tiempo de espera agotado. El servidor está tardando demasiado en responder.');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on FormatException {
        print('Error en formato de datos (intento $attempt)');

        if (attempt == maxRetries) {
          throw Exception(
              'Error en el formato de datos recibidos del servidor.');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } catch (e) {
        print('Error no manejado (intento $attempt): $e');

        if (attempt == maxRetries) {
          throw Exception('Error inesperado: $e');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    // Este código no debería alcanzarse debido al manejo de excepciones
    throw Exception('Error inesperado en updateVariety()');
  }

  // Eliminar una variedad (baja lógica) usando stored procedure
  Future<bool> deleteVariety(int id) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Eliminando variedad ID: $id (intento $attempt)');

        final response = await http
            .delete(Uri.parse('$variedadesUrl/$id'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final bool success = json.decode(response.body);
          print('Variedad eliminada exitosamente');
          return success;
        } else {
          final Map<String, dynamic> errorData = json.decode(response.body);
          print('Error al eliminar variedad: ${errorData['message']}');
          throw Exception(
              'Error al eliminar variedad: ${errorData['message']}');
        }
      } on SocketException {
        print('Error de conexión (intento $attempt)');

        if (attempt == maxRetries) {
          throw Exception(
              'Error de conexión. Verifique su conexión a internet y la configuración del servidor.');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on TimeoutException {
        print('Tiempo de espera agotado (intento $attempt)');

        if (attempt == maxRetries) {
          throw Exception(
              'Tiempo de espera agotado. El servidor está tardando demasiado en responder.');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on FormatException {
        print('Error en formato de datos (intento $attempt)');

        if (attempt == maxRetries) {
          throw Exception(
              'Error en el formato de datos recibidos del servidor.');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } catch (e) {
        print('Error no manejado (intento $attempt): $e');

        if (attempt == maxRetries) {
          throw Exception('Error inesperado: $e');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    // Este código no debería alcanzarse debido al manejo de excepciones
    throw Exception('Error inesperado en deleteVariety()');
  }
}
