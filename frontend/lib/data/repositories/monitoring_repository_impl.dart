import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../domain/repositories/user_repository.dart';
import '../../models/monitoreo_model.dart';
import 'package:postgres/postgres.dart';
import '../../core/config/flavor_config.dart';

class MonitoringRepositoryImpl implements MonitoringRepository {
  final PostgreSQLConnection connection = DatabaseConfig.connection;

  @override
  Future<Either<Failure, List<MonitoringModel>>> getMonitorings() async {
    try {
      final results = await connection.query(
        'SELECT * FROM pm_Monitoreos WHERE pmmo_Estatus = 1',
      );

      final monitorings = results
          .map((row) => MonitoringModel.fromJson(row.toColumnMap()))
          .toList();

      return Right(monitorings);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, MonitoringModel>> createMonitoring(
    MonitoringModel monitoring,
  ) async {
    try {
      final result = await connection.query(
        'INSERT INTO pm_Monitoreos (...) VALUES (...) RETURNING *',
        substitutionValues: {
          // Agregar valores del modelo
        },
      );

      if (result.isNotEmpty) {
        return Right(MonitoringModel.fromJson(result.first.toColumnMap()));
      }

      return Left(DatabaseFailure('No se pudo crear el monitoreo'));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
