import 'package:flutter/foundation.dart';
import '../models/monitoreo_model.dart';
import 'monitoreo_service.dart';
import 'intranet_service.dart';
import 'cache_service.dart';

class SincronizacionService {
  final MonitoreoService _monitoreoService;
  final IntranetService _intranetService;
  final CacheService _cacheService;

  // Estado de sincronización
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  final ValueNotifier<int> pendingChangesCount = ValueNotifier<int>(0);
  final ValueNotifier<String> lastSyncStatus = ValueNotifier<String>('');

  SincronizacionService({
    required MonitoreoService monitoreoService,
    required IntranetService intranetService,
    required CacheService cacheService,
  })  : _monitoreoService = monitoreoService,
        _intranetService = intranetService,
        _cacheService = cacheService {
    // Inicializar contador de cambios pendientes
    _updatePendingChangesCount();

    // Configurar escucha de cambios de conectividad
    _intranetService.isConnected.addListener(_handleConnectivityChange);
  }

  void _handleConnectivityChange() {
    // Si se recupera la conexión, intentar sincronizar automáticamente
    if (_intranetService.isConnected.value) {
      sincronizarCambiosPendientes();
    }
  }

  Future<void> _updatePendingChangesCount() async {
    final pendingChanges =
        await _cacheService.loadData('pending_monitoreos') ?? [];
    pendingChangesCount.value = pendingChanges.length;
    if (kDebugMode) {
      print('Cambios pendientes: ${pendingChangesCount.value}');
    }
  }

  /// Sincroniza todos los cambios pendientes con el servidor
  Future<bool> sincronizarCambiosPendientes() async {
    // Si ya estamos sincronizando o no hay conexión, salir
    if (isSyncing.value || !_intranetService.isConnected.value) {
      if (kDebugMode) {
        print(
            'No se puede sincronizar: ${isSyncing.value ? "Ya está sincronizando" : "Sin conexión"}');
      }
      return false;
    }

    try {
      isSyncing.value = true;
      lastSyncStatus.value = 'Sincronizando...';

      // Obtener cambios pendientes
      final List<dynamic> pendingChanges =
          await _cacheService.loadData('pending_monitoreos') ?? [];

      if (kDebugMode) {
        print(
            'SINCRONIZACIÓN: Encontrados ${pendingChanges.length} cambios pendientes');
        if (pendingChanges.isNotEmpty) {
          print('DETALLE DE CAMBIOS PENDIENTES:');
          for (var change in pendingChanges) {
            print('- Operación: ${change['operation']}');
            if (change['monitoreo'] != null) {
              final monitoreo = Monitoreo.fromJson(change['monitoreo']);
              print('  ID: ${monitoreo.pmmo_secuencia}');
              print('  Lote: ${monitoreo.pmlt_codigo}');
              print('  Temporal: ${monitoreo.isTemporary()}');
              print('  Offline created: ${monitoreo.isOfflineCreated}');
            }
          }
        }
      }

      if (pendingChanges.isEmpty) {
        isSyncing.value = false;
        lastSyncStatus.value = 'No hay cambios pendientes';
        return true;
      }

      int successCount = 0;
      List<dynamic> failedChanges = [];

      // Procesar cada cambio pendiente
      for (int i = 0; i < pendingChanges.length; i++) {
        final operation = pendingChanges[i];

        try {
          final String tipo = operation['operation'];
          final Map<String, dynamic> monitoreoJson = operation['monitoreo'];
          final Monitoreo monitoreo = Monitoreo.fromJson(monitoreoJson);

          if (kDebugMode) {
            print(
                'SINCRONIZANDO [${i + 1}/${pendingChanges.length}]: Operación: $tipo, ID: ${monitoreo.pmmo_secuencia}');
          }

          switch (tipo) {
            case 'create':
              try {
                // Si tiene ID negativo, es un registro creado offline
                if (monitoreo.isTemporary()) {
                  if (kDebugMode) {
                    print(
                        'Creando monitoreo temporal (ID negativo): ${monitoreo.pmmo_secuencia}');
                  }

                  // Crear una copia sin ID para que el servidor asigne uno
                  final nuevoMonitoreo = monitoreo.copyWith(
                    pmmo_secuencia: null,
                    isOfflineCreated:
                        false, // Ya no es offline después de sincronizar
                  );

                  if (kDebugMode) {
                    print('Datos a enviar al servidor:');
                    print(nuevoMonitoreo.toJson());
                  }

                  // Enviar al servidor - la función devuelve el nuevo monitoreo creado
                  await _monitoreoService.crearMonitoreo(nuevoMonitoreo);
                  successCount++;
                } else {
                  if (kDebugMode) {
                    print(
                        'Creando monitoreo con ID existente: ${monitoreo.pmmo_secuencia}');
                    print('Datos a enviar al servidor:');
                    print(monitoreo.toJson());
                  }

                  await _monitoreoService.crearMonitoreo(monitoreo);
                  successCount++;
                }
              } catch (e) {
                print('ERROR al crear monitoreo: $e');
                failedChanges.add(operation);
              }
              break;

            case 'update':
              try {
                // Si es un registro temporal, crearlo en lugar de actualizarlo
                if (monitoreo.isTemporary()) {
                  if (kDebugMode) {
                    print(
                        'Actualizando monitoreo temporal (creando nuevo): ${monitoreo.pmmo_secuencia}');
                  }

                  final nuevoMonitoreo = monitoreo.copyWith(
                    pmmo_secuencia: null,
                    isOfflineCreated: false,
                  );

                  if (kDebugMode) {
                    print('Datos a enviar al servidor:');
                    print(nuevoMonitoreo.toJson());
                  }

                  await _monitoreoService.crearMonitoreo(nuevoMonitoreo);
                  successCount++;
                } else {
                  if (kDebugMode) {
                    print(
                        'Actualizando monitoreo: ${monitoreo.pmmo_secuencia}');
                    print('Datos a enviar al servidor:');
                    print(monitoreo.toJson());
                  }

                  await _monitoreoService.actualizarMonitoreo(monitoreo);
                  successCount++;
                }
              } catch (e) {
                print('ERROR al actualizar monitoreo: $e');
                failedChanges.add(operation);
              }
              break;

            case 'delete':
              try {
                // Solo eliminar si tiene ID positivo (existe en el servidor)
                if (!monitoreo.isTemporary()) {
                  if (kDebugMode) {
                    print('Eliminando monitoreo: ${monitoreo.pmmo_secuencia}');
                  }

                  await _monitoreoService
                      .eliminarMonitoreo(monitoreo.pmmo_secuencia!);
                  successCount++;
                } else {
                  // Para registros temporales, simplemente considerarlo como eliminado
                  if (kDebugMode) {
                    print(
                        'Ignorando eliminación de monitoreo temporal: ${monitoreo.pmmo_secuencia}');
                  }
                  successCount++;
                }
              } catch (e) {
                print('ERROR al eliminar monitoreo: $e');
                failedChanges.add(operation);
              }
              break;

            default:
              if (kDebugMode) {
                print('Operación desconocida: $tipo');
              }
              failedChanges.add(operation);
          }
        } catch (e) {
          if (kDebugMode) {
            print('ERROR general al sincronizar operación: $e');
            print('Detalles de la operación fallida:');
            print(operation);
          }
          failedChanges.add(operation);
        }
      }

      // Guardar solo las operaciones que fallaron
      await _cacheService.saveData('pending_monitoreos', failedChanges);

      // Actualizar estado
      final String mensaje = failedChanges.isEmpty
          ? 'Sincronización completada correctamente'
          : 'Sincronización parcial: $successCount de ${pendingChanges.length} cambios completados';

      if (kDebugMode) {
        print('RESULTADO SINCRONIZACIÓN: $mensaje');
        print('Fallos: ${failedChanges.length}');
      }

      lastSyncStatus.value = mensaje;
      await _updatePendingChangesCount();

      // Recargar los datos actuales después de sincronizar
      try {
        final newData = await _monitoreoService.getMonitoreos();
        await actualizarDatosLocales(newData);
      } catch (e) {
        print('Error al actualizar datos locales después de sincronizar: $e');
      }

      return failedChanges.isEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('ERROR GENERAL durante la sincronización: $e');
      }
      lastSyncStatus.value = 'Error durante la sincronización: $e';
      return false;
    } finally {
      isSyncing.value = false;
    }
  }

  /// Registra un cambio local para sincronización posterior
  Future<void> registrarCambioLocal(
      String operacion, Monitoreo monitoreo) async {
    // Cargar cambios existentes
    List<dynamic> pendingChanges =
        await _cacheService.loadData('pending_monitoreos') ?? [];

    if (kDebugMode) {
      print(
          'Registrando cambio local: $operacion, ID: ${monitoreo.pmmo_secuencia}');
    }

    // Añadir el nuevo cambio
    pendingChanges.add({
      'operation': operacion,
      'monitoreo': monitoreo.toJson(),
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Guardar los cambios actualizados
    await _cacheService.saveData('pending_monitoreos', pendingChanges);
    await _updatePendingChangesCount();
  }

  /// Actualiza los datos locales con los monitoreos proporcionados
  Future<void> actualizarDatosLocales(List<Monitoreo> monitoreos) async {
    if (kDebugMode) {
      print('Actualizando datos locales: ${monitoreos.length} monitoreos');
    }
    await _cacheService.saveData(
        'monitoreos_data', monitoreos.map((m) => m.toJson()).toList());
  }

  /// Obtiene monitoreos locales desde la caché
  Future<List<Monitoreo>> obtenerMonitoreosLocales() async {
    final List<dynamic> cachedData =
        await _cacheService.loadData('monitoreos_data') ?? [];
    final monitoreos =
        cachedData.map<Monitoreo>((json) => Monitoreo.fromJson(json)).toList();

    if (kDebugMode) {
      print('Obtenidos ${monitoreos.length} monitoreos locales');
    }

    return monitoreos;
  }

  /// Limpiar recursos al desecharse
  void dispose() {
    _intranetService.isConnected.removeListener(_handleConnectivityChange);
    isSyncing.dispose();
    pendingChangesCount.dispose();
    lastSyncStatus.dispose();
  }
}
