import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/unidad_cultivo_model.dart';
import '../core/config/flavor_config.dart'; // Importación de configuración centralizada

class UnidadCultivoService {
  // Singleton para asegurar una única instancia
  static final UnidadCultivoService _instance =
      UnidadCultivoService._internal();
  factory UnidadCultivoService() => _instance;
  UnidadCultivoService._internal();

  // Getter para URL de unidades de cultivo usando ApiConfig
  String get unidadesCultivoUrl => ApiConfig().unidadesCultivoUrl;

  // Obtener todas las unidades de cultivo usando stored procedure
  // Método actualizado para getUnidadesCultivo en el servicio Flutter
  Future<List<UnidadCultivo>> getUnidadesCultivo({
    String? busqueda,
    String? estatus,
  }) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // Construir parámetros de consulta
        final Map<String, String> queryParams = {};

        // Solo añadir los parámetros que tienen valor
        if (busqueda != null && busqueda.isNotEmpty) {
          queryParams['busqueda'] = busqueda;
        }

        if (estatus != null && estatus != 'Todos') {
          queryParams['estatus'] = estatus;
        }

        final uri =
            Uri.parse(unidadesCultivoUrl).replace(queryParameters: queryParams);

        print('Obteniendo unidades de cultivo desde: $uri (intento $attempt)');
        print('Parámetros de búsqueda: $queryParams');

        // Tiempo de espera reducido ya que usamos stored procedure
        final response =
            await http.get(uri).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final dynamic jsonData = json.decode(response.body);
          List<dynamic> data;

          // Manejar diferentes formatos de respuesta
          if (jsonData is Map<String, dynamic> &&
              jsonData.containsKey('data')) {
            // Nuevo formato con stored procedure
            data = jsonData['data'];
            print(
                'Formato de respuesta: Nuevo (SP), Unidades encontradas: ${data.length}');
          } else if (jsonData is List) {
            // Formato anterior (directo)
            data = jsonData;
            print(
                'Formato de respuesta: Antiguo (directo), Unidades encontradas: ${data.length}');
          } else {
            throw Exception('Formato de respuesta no reconocido');
          }

          print('Unidades de cultivo obtenidas exitosamente: ${data.length}');
          return data.map((json) => UnidadCultivo.fromJson(json)).toList();
        } else {
          print('Error ${response.statusCode}: ${response.body}');
          throw Exception(
              'Error al cargar unidades de cultivo: ${response.statusCode}');
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
    throw Exception('Error inesperado en getUnidadesCultivo()');
  }

  // Obtener una unidad de cultivo por secuencia usando stored procedure
  Future<UnidadCultivo> getUnidadCultivoById(int secuencia) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print(
            'Obteniendo unidad de cultivo con secuencia: $secuencia (intento $attempt)');

        // Tiempo de espera reducido ya que usamos stored procedure
        final response = await http
            .get(Uri.parse('$unidadesCultivoUrl/$secuencia'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final dynamic jsonData = json.decode(response.body);

          // Manejar diferentes formatos de respuesta
          if (jsonData is Map<String, dynamic> &&
              jsonData.containsKey('data')) {
            // Nuevo formato con stored procedure
            print('Formato de respuesta: Nuevo (SP)');
            return UnidadCultivo.fromJson(jsonData['data']);
          } else {
            // Formato anterior (directo)
            print('Formato de respuesta: Antiguo (directo)');
            return UnidadCultivo.fromJson(jsonData);
          }
        } else {
          print('Error ${response.statusCode}: ${response.body}');
          throw Exception(
              'Error al cargar la unidad de cultivo: ${response.statusCode}');
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
    throw Exception('Error inesperado en getUnidadCultivoById()');
  }

  // Crear una nueva unidad de cultivo usando stored procedure
  Future<int> createUnidadCultivo(UnidadCultivo unidad) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print(
            'Creando nueva unidad de cultivo: ${unidad.codigo} (intento $attempt)');

        // Obtener los datos para enviar usando el método toJson del modelo
        // Esto aprovecha la lógica específica implementada en el modelo
        final Map<String, dynamic> bodyData = unidad.toJson();

        // Asegurar que los nombres de los campos sigan la convención del backend
        if (unidad.creadoPor != null) {
          bodyData['creadopor'] = unidad.creadoPor;
        }

        final response = await http
            .post(
              Uri.parse(unidadesCultivoUrl),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(bodyData),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 201 || response.statusCode == 200) {
          final dynamic jsonData = json.decode(response.body);

          // Manejar diferentes formatos de respuesta
          if (jsonData is Map<String, dynamic>) {
            if (jsonData.containsKey('success') &&
                jsonData.containsKey('data')) {
              // Nuevo formato con stored procedure
              print('Formato de respuesta: Nuevo (SP)');
              if (jsonData['success'] == true) {
                if (jsonData['data'] is Map<String, dynamic>) {
                  return jsonData['data']['secuencia'];
                } else {
                  throw Exception('Formato de respuesta inesperado para el ID');
                }
              } else {
                throw Exception(
                    jsonData['message'] ?? 'Error al crear unidad de cultivo');
              }
            } else if (jsonData.containsKey('secuencia')) {
              // Formato directo con secuencia
              return jsonData['secuencia'];
            } else if (jsonData.containsKey('id')) {
              // Formato directo con id
              return jsonData['id'];
            } else {
              throw Exception('Formato de respuesta no reconocido');
            }
          } else if (jsonData is int) {
            // Caso donde el servidor devuelve directamente el ID
            return jsonData;
          } else {
            throw Exception('Formato de respuesta no reconocido');
          }
        } else {
          // Intentar extraer mensaje de error
          final Map<String, dynamic> errorData = json.decode(response.body);
          print('Error al crear unidad de cultivo: ${errorData['message']}');
          throw Exception(
              'Error al crear unidad de cultivo: ${errorData['message']}');
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
    throw Exception('Error inesperado en createUnidadCultivo()');
  }

  // Actualizar una unidad de cultivo existente usando stored procedure
  Future<bool> updateUnidadCultivo(UnidadCultivo unidad) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print(
            'Actualizando unidad de cultivo secuencia: ${unidad.secuencia} (intento $attempt)');

        // Obtener los datos para enviar usando el método toJson del modelo
        // Esto aprovecha la lógica específica implementada en el modelo
        final Map<String, dynamic> bodyData = unidad.toJson();

        // Asegurar que los nombres de los campos sigan la convención del backend
        if (unidad.modificadoPor != null) {
          bodyData['modificadopor'] = unidad.modificadoPor;
        }

        final response = await http
            .put(
              Uri.parse('$unidadesCultivoUrl/${unidad.secuencia}'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(bodyData),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final dynamic jsonData = json.decode(response.body);

          // Manejar diferentes formatos de respuesta
          if (jsonData is Map<String, dynamic> &&
              jsonData.containsKey('success')) {
            // Nuevo formato con stored procedure
            print('Formato de respuesta: Nuevo (SP)');
            if (jsonData['success'] == true) {
              return true;
            } else {
              throw Exception(jsonData['message'] ??
                  'Error al actualizar unidad de cultivo');
            }
          } else if (jsonData is bool) {
            // Formato anterior (directo)
            print('Formato de respuesta: Antiguo (directo)');
            return jsonData;
          } else {
            // Si no podemos interpretar la respuesta pero el código es 200, asumimos éxito
            return true;
          }
        } else {
          // Intentar extraer mensaje de error
          final Map<String, dynamic> errorData = json.decode(response.body);
          print(
              'Error al actualizar unidad de cultivo: ${errorData['message']}');
          throw Exception(
              'Error al actualizar unidad de cultivo: ${errorData['message']}');
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
    throw Exception('Error inesperado en updateUnidadCultivo()');
  }

  // Eliminar una unidad de cultivo (baja lógica) usando stored procedure
  Future<bool> deleteUnidadCultivo(int secuencia) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print(
            'Eliminando unidad de cultivo secuencia: $secuencia (intento $attempt)');

        final response = await http
            .delete(Uri.parse('$unidadesCultivoUrl/$secuencia'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          // Intentar parsear respuesta JSON
          try {
            final dynamic jsonData = json.decode(response.body);

            // Manejar diferentes formatos de respuesta
            if (jsonData is Map<String, dynamic> &&
                jsonData.containsKey('success')) {
              // Nuevo formato con stored procedure
              print('Formato de respuesta: Nuevo (SP)');
              if (jsonData['success'] == true) {
                return true;
              } else {
                throw Exception(jsonData['message'] ??
                    'Error al eliminar unidad de cultivo');
              }
            } else if (jsonData is bool) {
              // Formato anterior (directo)
              print('Formato de respuesta: Antiguo (directo)');
              return jsonData;
            } else {
              // Si no podemos interpretar la respuesta pero el código es 200, asumimos éxito
              return true;
            }
          } catch (e) {
            // Si no podemos parsear el JSON pero el código de estado es 200, asumimos éxito
            return true;
          }
        } else {
          // Intentar extraer mensaje de error
          final Map<String, dynamic> errorData = json.decode(response.body);
          print('Error al eliminar unidad de cultivo: ${errorData['message']}');
          throw Exception(
              'Error al eliminar unidad de cultivo: ${errorData['message']}');
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
    throw Exception('Error inesperado en deleteUnidadCultivo()');
  }
}
