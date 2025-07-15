import 'package:either_dart/either.dart';
import '../../data/models/user_model.dart';

abstract class UserRepository {
  Future<Either<String, UserModel>> login(String username, String password);
  Future<Either<String, UserModel>> getUserById(int id);
  Future<Either<String, List<UserModel>>> getUsers();
}
