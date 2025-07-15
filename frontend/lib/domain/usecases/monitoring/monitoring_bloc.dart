import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../domain/repositories/monitoring_repository.dart';
import '../../../data/models/monitoring_model.dart';

part 'monitoring_event.dart';
part 'monitoring_state.dart';
part 'monitoring_bloc.freezed.dart';

class MonitoringBloc extends Bloc<MonitoringEvent, MonitoringState> {
  final MonitoringRepository repository;

  MonitoringBloc({required this.repository})
      : super(const MonitoringState.initial()) {
    on<MonitoringEvent>((event, emit) async {
      await event.map(
        started: (e) async {
          emit(const MonitoringState.loading());
          final result = await repository.getMonitorings();
          result.fold(
            (failure) => emit(MonitoringState.error(failure.toString())),
            (monitorings) => emit(MonitoringState.loaded(monitorings)),
          );
        },
        created: (e) async {
          emit(const MonitoringState.loading());
          final result = await repository.createMonitoring(e.monitoring);
          result.fold(
            (failure) => emit(MonitoringState.error(failure.toString())),
            (monitoring) => emit(MonitoringState.created(monitoring)),
          );
        },
      );
    });
  }
}
