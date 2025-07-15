import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import '../../core/config/flavor_config.dart';
import '../../domain/repositories/user_repository.dart';
import '../models/user_model.dart';

class UserRepositoryImpl implements UserRepository {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: DatabaseConfig.apiUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));

  @override
  Future<Either<String, UserModel>> login(
      String username, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'username': username,
        'password': password,
      });

      if (response.statusCode == 200 && response.data['success']) {
        return Right(UserModel.fromMap(response.data['user']));
      }

      return Left(response.data['message'] ?? 'Error de autenticación');
    } catch (e) {
      return Left('Error de autenticación: $e');
    }
  }

  @override
  Future<Either<String, UserModel>> getUserById(int id) async {
    try {
      final response = await _dio.get('/users/$id');

      if (response.statusCode == 200 && response.data['success']) {
        return Right(UserModel.fromMap(response.data['user']));
      }

      return Left(response.data['message'] ?? 'Usuario no encontrado');
    } catch (e) {
      return Left('Error al obtener usuario: $e');
    }
  }

  @override
  Future<Either<String, List<UserModel>>> getUsers() async {
    try {
      final response = await _dio.get('/users');

      if (response.statusCode == 200 && response.data['success']) {
        final users = (response.data['users'] as List)
            .map((user) => UserModel.fromMap(user))
            .toList();
        return Right(users);
      }

      return Left(response.data['message'] ?? 'Error al obtener usuarios');
    } catch (e) {
      return Left('Error al obtener usuarios: $e');
    }
  }
}
