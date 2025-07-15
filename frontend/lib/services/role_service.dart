import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/role_model.dart';
import '../core/config/flavor_config.dart';

class RoleService {
  static final RoleService _instance = RoleService._internal();
  factory RoleService() => _instance;
  RoleService._internal();

  String get rolesUrl => ApiConfig().rolesUrl;

  // Obtener todos los roles - usando stored procedure
  Future<List<Role>> getRoles({String? busqueda}) async {
    int maxRetries = 3;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Obteniendo roles, intento $attempt');

        final Uri uri;
        if (busqueda != null && busqueda.isNotEmpty) {
          uri = Uri.parse('$rolesUrl?busqueda=$busqueda');
        } else {
          uri = Uri.parse(rolesUrl);
        }

        // Reducido el timeout a 15 segundos ya que ahora usamos stored procedure
        final response = await http.get(uri).timeout(Duration(seconds: 15));

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          print('Roles obtenidos exitosamente: ${data.length}');
          return data.map((json) => Role.fromJson(json)).toList();
        } else {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['message'] ?? 'Error desconocido';
          if (kDebugMode) {
            print('Error ${response.statusCode}: $errorMsg');
          }
          throw Exception('Error al cargar roles: $errorMsg');
        }
      } on SocketException {
        print('Error de conexión en intento $attempt');
        if (attempt == maxRetries) {
          throw Exception(
              'Error de conexión. Verifique su conexión a internet y la configuración del servidor.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on TimeoutException {
        print('Timeout en intento $attempt');
        if (attempt == maxRetries) {
          throw Exception(
              'Tiempo de espera agotado. El servidor está tardando demasiado en responder.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on FormatException catch (e) {
        print('Error de formato en intento $attempt: $e');
        if (attempt == maxRetries) {
          throw Exception(
              'Error en el formato de datos recibidos del servidor: $e');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } catch (e) {
        if (kDebugMode) {
          print('Error no manejado en intento $attempt: $e');
        }
        if (attempt == maxRetries) {
          throw Exception('Error inesperado: $e');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    // Este código no debería alcanzarse debido al manejo de excepciones anterior
    throw Exception('Error inesperado en getRoles()');
  }

  // Obtener roles para dropdown usando stored procedure
  Future<List<Map<String, dynamic>>> getDropdownRoles() async {
    int maxRetries = 2;
    int retryDelay = 500; // milisegundos más corto para esta operación simple

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Obteniendo dropdown de roles, intento $attempt');

        // Timeout más corto para esta operación simple
        final response = await http
            .get(Uri.parse('$rolesUrl/dropdown'))
            .timeout(Duration(seconds: 10));

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          print('Dropdown roles obtenidos: ${data.length}');
          return List<Map<String, dynamic>>.from(data);
        } else {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['message'] ?? 'Error desconocido';
          throw Exception('Error al obtener dropdown de roles: $errorMsg');
        }
      } catch (e) {
        print('Error al obtener dropdown roles (intento $attempt): $e');

        if (attempt == maxRetries) {
          // Si fallamos todos los intentos, intentar con la ruta normal
          try {
            print('Intentando obtener roles completos como fallback');
            final roles = await getRoles();
            return roles
                .map((r) => {'id': r.id, 'descripcion': r.descripcion})
                .toList();
          } catch (fallbackError) {
            print('Error en fallback: $fallbackError');
            throw Exception('No se pudieron obtener los roles: $e');
          }
        }

        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    // Fallback a roles normales
    final roles = await getRoles();
    return roles
        .map((r) => {'id': r.id, 'descripcion': r.descripcion})
        .toList();
  }

  // Obtener un rol por ID usando stored procedure
  Future<Role> getRoleById(int id) async {
    int maxRetries = 3;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Obteniendo rol con ID: $id, intento $attempt');

        final response = await http
            .get(
              Uri.parse('$rolesUrl/$id'),
            )
            .timeout(Duration(seconds: 15));

        if (response.statusCode == 200) {
          final dynamic data = json.decode(response.body);
          print('Rol obtenido exitosamente');
          return Role.fromJson(data);
        } else {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['message'] ?? 'Error desconocido';
          if (kDebugMode) {
            print('Error ${response.statusCode}: $errorMsg');
          }
          throw Exception('Error al cargar el rol: $errorMsg');
        }
      } on SocketException {
        print('Error de conexión en intento $attempt');
        if (attempt == maxRetries) {
          throw Exception(
              'Error de conexión. Verifique su conexión a internet y la configuración del servidor.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on TimeoutException {
        print('Timeout en intento $attempt');
        if (attempt == maxRetries) {
          throw Exception(
              'Tiempo de espera agotado. El servidor está tardando demasiado en responder.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on FormatException {
        print('Error de formato en intento $attempt');
        if (attempt == maxRetries) {
          throw Exception(
              'Error en el formato de datos recibidos del servidor.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } catch (e) {
        if (kDebugMode) {
          print('Error no manejado en intento $attempt: $e');
        }
        if (attempt == maxRetries) {
          throw Exception('Error inesperado: $e');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en getRoleById()');
  }

  // Crear un nuevo rol usando stored procedure
  Future<int> createRole(Role role) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Creando rol: ${role.descripcion}, intento $attempt');

        final response = await http
            .post(
              Uri.parse(rolesUrl),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'descripcion': role.descripcion,
                'estatus': role.estatus,
                'creadoPor': role.creadoPor,
              }),
            )
            .timeout(Duration(seconds: 30));

        if (response.statusCode == 201) {
          // Manejo de ambos formatos de respuesta (el antiguo y el nuevo)
          final dynamic result = json.decode(response.body);
          int rolId;

          if (result is int) {
            // Formato antiguo: directamente el ID
            rolId = result;
          } else if (result is Map) {
            // Nuevo formato: objeto con success, message y rol_id
            rolId = result['rol_id'] ?? 0;
          } else {
            // Formato inesperado
            rolId = 0;
          }

          print('Rol creado exitosamente con ID: $rolId');
          return rolId;
        } else {
          final dynamic errorData = json.decode(response.body);
          final String errorMsg = errorData is Map
              ? (errorData['message'] ?? 'Error desconocido')
              : 'Error al crear rol';

          if (kDebugMode) {
            print('Error ${response.statusCode}: $errorMsg');
          }
          throw Exception(errorMsg);
        }
      } on SocketException {
        print('Error de conexión en intento $attempt');
        if (attempt == maxRetries) {
          throw Exception(
              'Error de conexión. Verifique su conexión a internet y la configuración del servidor.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on TimeoutException {
        print('Timeout en intento $attempt');
        if (attempt == maxRetries) {
          throw Exception(
              'Tiempo de espera agotado. El servidor está tardando demasiado en responder.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on FormatException {
        print('Error de formato en intento $attempt');
        if (attempt == maxRetries) {
          throw Exception(
              'Error en el formato de datos recibidos del servidor.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } catch (e) {
        if (kDebugMode) {
          print('Error no manejado en intento $attempt: $e');
        }
        if (attempt == maxRetries) {
          throw Exception('Error inesperado: $e');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en createRole()');
  }

  // Actualizar un rol usando stored procedure
  Future<bool> updateRole(Role role) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Actualizando rol ID: ${role.id}, intento $attempt');

        final response = await http
            .put(
              Uri.parse('$rolesUrl/${role.id}'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'descripcion': role.descripcion,
                'estatus': role.estatus,
                'modificadoPor': role.modificadoPor,
              }),
            )
            .timeout(Duration(seconds: 30));

        if (response.statusCode == 200) {
          // Manejar ambos formatos de respuesta
          final dynamic result = json.decode(response.body);
          bool success;

          if (result is bool) {
            // Formato antiguo: directamente un booleano
            success = result;
          } else if (result is Map && result.containsKey('success')) {
            // Nuevo formato: objeto con success y message
            success = result['success'] as bool;
          } else {
            // Formato inesperado
            success = true;
          }

          print('Rol actualizado exitosamente');
          return success;
        } else {
          final dynamic errorData = json.decode(response.body);
          final String errorMsg = errorData is Map
              ? (errorData['message'] ?? 'Error desconocido')
              : 'Error al actualizar rol';

          if (kDebugMode) {
            print('Error ${response.statusCode}: $errorMsg');
          }
          throw Exception(errorMsg);
        }
      } on SocketException {
        print('Error de conexión en intento $attempt');
        if (attempt == maxRetries) {
          throw Exception(
              'Error de conexión. Verifique su conexión a internet y la configuración del servidor.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on TimeoutException {
        print('Timeout en intento $attempt');
        if (attempt == maxRetries) {
          throw Exception(
              'Tiempo de espera agotado. El servidor está tardando demasiado en responder.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on FormatException {
        print('Error de formato en intento $attempt');
        if (attempt == maxRetries) {
          throw Exception(
              'Error en el formato de datos recibidos del servidor.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } catch (e) {
        if (kDebugMode) {
          print('Error no manejado en intento $attempt: $e');
        }
        if (attempt == maxRetries) {
          throw Exception('Error inesperado: $e');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en updateRole()');
  }

  // Eliminar un rol usando stored procedure
  Future<bool> deleteRole(int id) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Eliminando rol ID: $id, intento $attempt');

        final response = await http
            .delete(
              Uri.parse('$rolesUrl/$id'),
            )
            .timeout(Duration(seconds: 30));

        if (response.statusCode == 200) {
          // Manejar ambos formatos de respuesta
          final dynamic result = json.decode(response.body);
          bool success;

          if (result is bool) {
            // Formato antiguo: directamente un booleano
            success = result;
          } else if (result is Map && result.containsKey('success')) {
            // Nuevo formato: objeto con success y message
            success = result['success'] as bool;
          } else {
            // Formato inesperado
            success = true;
          }

          print('Rol eliminado exitosamente');
          return success;
        } else {
          final dynamic errorData = json.decode(response.body);
          final String errorMsg = errorData is Map
              ? (errorData['message'] ?? 'Error desconocido')
              : 'Error al eliminar rol';

          if (kDebugMode) {
            print('Error ${response.statusCode}: $errorMsg');
          }
          throw Exception(errorMsg);
        }
      } on SocketException {
        print('Error de conexión en intento $attempt');
        if (attempt == maxRetries) {
          throw Exception(
              'Error de conexión. Verifique su conexión a internet y la configuración del servidor.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on TimeoutException {
        print('Timeout en intento $attempt');
        if (attempt == maxRetries) {
          throw Exception(
              'Tiempo de espera agotado. El servidor está tardando demasiado en responder.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on FormatException {
        print('Error de formato en intento $attempt');
        if (attempt == maxRetries) {
          throw Exception(
              'Error en el formato de datos recibidos del servidor.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } catch (e) {
        if (kDebugMode) {
          print('Error no manejado en intento $attempt: $e');
        }
        if (attempt == maxRetries) {
          throw Exception('Error inesperado: $e');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en deleteRole()');
  }
}
