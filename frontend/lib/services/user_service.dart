import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../core/config/flavor_config.dart'; // Importar configuración centralizada

class UserService {
  // Singleton para asegurar una única instancia
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  // Usar las URLs desde la configuración centralizada
  String get usersUrl => ApiConfig().usersUrl;

  // Obtener todos los usuarios con filtros opcionales - usando stored procedure
  Future<List<User>> getUsers(
      {String? rol, String? estatus, String? busqueda}) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // Construir parámetros de consulta
        final queryParams = <String, String>{};
        if (rol != null && rol != 'Todos') queryParams['rol'] = rol;
        if (estatus != null && estatus != 'Todos')
          queryParams['estatus'] = estatus;
        if (busqueda != null && busqueda.isNotEmpty)
          queryParams['busqueda'] = busqueda;

        // Crear URI con parámetros
        final uri = Uri.parse(usersUrl).replace(queryParameters: queryParams);

        print('Obteniendo usuarios desde: $uri');

        // Tiempo de espera reducido ya que usamos stored procedure
        final response = await http.get(uri).timeout(Duration(seconds: 15));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true && data['data'] != null) {
            print('Usuarios obtenidos exitosamente: ${data['data'].length}');
            return (data['data'] as List)
                .map((userJson) => User.fromJson(userJson))
                .toList();
          } else {
            throw Exception('Error en la respuesta: ${data['message']}');
          }
        } else {
          throw Exception('Error al obtener usuarios: ${response.statusCode}');
        }
      } catch (e) {
        print('Error al obtener usuarios (intento $attempt): $e');

        if (attempt == maxRetries) {
          throw Exception('Error de conexión: $e');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en getUsers()');
  }

  // Obtener un usuario por ID - usando stored procedure
  Future<User> getUserById(int id) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Obteniendo usuario con ID: $id (intento $attempt)');
        final response = await http
            .get(Uri.parse('$usersUrl/$id'))
            .timeout(Duration(seconds: 15)); // Tiempo reducido

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true && data['data'] != null) {
            print('Usuario obtenido exitosamente');
            return User.fromJson(data['data']);
          } else {
            throw Exception('Error en la respuesta: ${data['message']}');
          }
        } else {
          throw Exception('Error al obtener usuario: ${response.statusCode}');
        }
      } catch (e) {
        print('Error al obtener usuario (intento $attempt): $e');

        if (attempt == maxRetries) {
          throw Exception('Error de conexión: $e');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en getUserById()');
  }

  // Crear un nuevo usuario
  Future<int> createUser(User user) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Creando nuevo usuario: ${user.usuario} (intento $attempt)');
        final response = await http
            .post(
              Uri.parse(usersUrl),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(user.toJson()),
            )
            .timeout(Duration(seconds: 30)); // Reducido de 45 a 30 segundos

        if (response.statusCode == 201) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true && data['data'] != null) {
            print('Usuario creado exitosamente con ID: ${data['data']['id']}');
            return data['data']['id'];
          } else {
            throw Exception('Error en la respuesta: ${data['message']}');
          }
        } else {
          final errorData = json.decode(response.body);
          throw Exception('Error al crear usuario: ${errorData['message']}');
        }
      } catch (e) {
        print('Error al crear usuario (intento $attempt): $e');

        if (attempt == maxRetries) {
          throw Exception('Error de conexión: $e');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en createUser()');
  }

  // Actualizar un usuario existente
  Future<bool> updateUser(User user) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Actualizando usuario ID: ${user.id} (intento $attempt)');
        final response = await http
            .put(
              Uri.parse('$usersUrl/${user.id}'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(user.toJson()),
            )
            .timeout(Duration(seconds: 30)); // Reducido de 45 a 30 segundos

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          print('Usuario actualizado exitosamente');
          return data['success'] == true;
        } else {
          final errorData = json.decode(response.body);
          throw Exception(
              'Error al actualizar usuario: ${errorData['message']}');
        }
      } catch (e) {
        print('Error al actualizar usuario (intento $attempt): $e');

        if (attempt == maxRetries) {
          throw Exception('Error de conexión: $e');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en updateUser()');
  }

  // Eliminar un usuario (baja lógica) - ahora usando stored procedure
  Future<bool> deleteUser(int id) async {
    int maxRetries = 2;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Eliminando usuario ID: $id (intento $attempt)');

        final response = await http
            .delete(Uri.parse('$usersUrl/$id'))
            .timeout(Duration(seconds: 30)); // Reducido de 45 a 30 segundos

        print('Respuesta recibida: ${response.statusCode}');

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          print('Respuesta decodificada: $data');
          return data['success'] == true;
        } else {
          final errorData = json.decode(response.body);
          throw Exception('Error al eliminar usuario: ${errorData['message']}');
        }
      } catch (e) {
        print('Error al eliminar usuario (intento $attempt): $e');

        if (attempt == maxRetries) {
          throw Exception('Error de conexión: $e');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en deleteUser()');
  }

  // Obtener lista de roles - usando el endpoint optimizado de roles
  Future<List<Map<String, dynamic>>> getRoles() async {
    int maxRetries = 3;
    int retryDelay = 1000; // milisegundos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Obteniendo roles para usuario, intento $attempt');

        // Usar el endpoint de dropdown que es más ligero
        final response = await http
            .get(Uri.parse('$usersUrl/roles/lista'))
            .timeout(Duration(seconds: 15)); // Tiempo reducido

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true && data['data'] != null) {
            print('Roles obtenidos exitosamente: ${data['data'].length}');
            return List<Map<String, dynamic>>.from(data['data']);
          } else {
            throw Exception('Error en la respuesta: ${data['message']}');
          }
        } else {
          throw Exception('Error al obtener roles: ${response.statusCode}');
        }
      } catch (e) {
        print('Error al obtener roles (intento $attempt): $e');

        if (attempt == maxRetries) {
          throw Exception(
              'Error de conexión después de $maxRetries intentos: $e');
        }

        print('Reintentando en ${retryDelay / 1000} segundos...');
        await Future.delayed(Duration(milliseconds: retryDelay));
        // Incrementar el tiempo de espera para cada reintento
        retryDelay *= 2;
      }
    }

    // Este código nunca debería alcanzarse debido al manejo de excepciones arriba
    throw Exception('Error inesperado en getRoles()');
  }
}
