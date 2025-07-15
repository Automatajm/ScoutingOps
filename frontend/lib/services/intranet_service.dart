import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../core/config/flavor_config.dart'; // Cambiar la importación a flavor_config.dart

class IntranetService {
  static final IntranetService _instance = IntranetService._internal();
  factory IntranetService() => _instance;

  IntranetService._internal() {
    // Subscribirse a los cambios en la configuración
    ApiConfig().addListener(_onConfigChanged);
  }

  // Usar la URL desde la configuración centralizada
  String get _serverUrl => ApiConfig().baseUrl;

  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  Timer? _connectivityCheckTimer;

  Future<void> initialize() async {
    if (kDebugMode) {
      print('Iniciando IntranetService con URL base: $_serverUrl');
    }

    // Verificar conexión inicial
    await checkIntranetConnection();

    // Programar verificaciones periódicas
    _connectivityCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      checkIntranetConnection();
    });
  }

  Future<bool> checkIntranetConnection() async {
    try {
      // Usar la ruta de prueba del API
      if (kDebugMode) {
        print('Verificando conexión a: $_serverUrl');
      }

      final response = await http
          .get(Uri.parse(
              '$_serverUrl/')) // Esta ruta corresponde al endpoint '/' que devuelve {message: 'API funcionando correctamente'}
          .timeout(const Duration(seconds: 5));

      final bool connected =
          response.statusCode >= 200 && response.statusCode < 400;

      // Actualiza el estado solo si hay un cambio para evitar notificaciones innecesarias
      if (isConnected.value != connected) {
        isConnected.value = connected;
      }

      if (kDebugMode) {
        print(
            'Estado de conexión a intranet: ${connected ? 'Conectado' : 'Desconectado'} - Status code: ${response.statusCode}');
        print(
            'Respuesta: ${response.body}'); // Imprime la respuesta para depuración
      }

      return connected;
    } catch (e) {
      if (kDebugMode) {
        print('Error al verificar conexión a intranet: $e');
      }

      // Actualiza el estado solo si hay un cambio
      if (isConnected.value != false) {
        isConnected.value = false;
      }

      return false;
    }
  }

  // Método para forzar la verificación de conexión (útil para añadir a un botón de reintento)
  Future<bool> refreshConnection() async {
    return await checkIntranetConnection();
  }

  // Método privado que se llama cuando cambia la configuración
  void _onConfigChanged() {
    if (kDebugMode) {
      print(
          'Se detectó un cambio en la configuración de la API. Nueva URL: ${ApiConfig().baseUrl}');
    }

    // Verificar la conexión con la nueva URL
    checkIntranetConnection();
  }

  void dispose() {
    _connectivityCheckTimer?.cancel();

    // Importante: eliminar el listener para evitar memory leaks
    ApiConfig().removeListener(_onConfigChanged);
  }
}
