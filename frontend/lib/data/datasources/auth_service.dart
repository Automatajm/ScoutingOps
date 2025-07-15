import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../../core/config/flavor_config.dart'; // Mantenemos la misma ruta de importación
import '../models/user_model.dart';
import '../../presentation/pages/auth/login_screen.dart';

class AuthService extends ChangeNotifier {
  final ApiConfig _apiConfig;
  late Dio _dio;

  UserModel? _currentUser;
  Timer? _inactivityTimer;
  Timer? _warningTimer;
  Timer? _loginScreenTimer;

  // Configuración de tiempos de inactividad
  static const inactivityTimeout = Duration(minutes: 30);
  static const warningBeforeTimeout = Duration(seconds: 30);
  static const loginScreenTimeout = Duration(minutes: 30);

  DateTime _lastActivityTime = DateTime.now();
  bool _isShowingWarning = false;
  // Añadir una variable para throttling
  DateTime _lastResetTime = DateTime.now();

  // Añadir un flag para controlar el estado de procesamiento de login
  bool _isProcessingLogin = false;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  bool get isMonitoreador => _currentUser?.isMonitoreador ?? false;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get mustFilterByUser => isMonitoreador && !isAdmin;

  // Variable global para almacenar el contexto de la aplicación
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Constructor actualizado para recibir ApiConfig
  AuthService(this._apiConfig) {
    _initDio();

    // Suscribirse a cambios en la configuración
    _apiConfig.addListener(_updateDioBaseUrl);
  }

  // Inicializar Dio con la configuración actual
  void _initDio() {
    _dio = Dio(BaseOptions(
      baseUrl: _apiConfig.apiUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
    ));
  }

  // Actualizar la URL base cuando cambia la configuración
  void _updateDioBaseUrl() {
    _dio.options.baseUrl = _apiConfig.apiUrl;
    debugPrint('URL base de Auth Service actualizada: ${_dio.options.baseUrl}');
  }

  void _startInactivityTimer(BuildContext? context) {
    _inactivityTimer?.cancel();
    _warningTimer?.cancel();
    _isShowingWarning = false;

    _inactivityTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      final now = DateTime.now();
      final difference = now.difference(_lastActivityTime);
      final timeUntilTimeout = inactivityTimeout - difference;

      // Si es hora de mostrar la advertencia (30 segundos antes del timeout)
      if (timeUntilTimeout <= warningBeforeTimeout && !_isShowingWarning) {
        _showWarningDialog(timeUntilTimeout.inSeconds);
      }

      // Si se ha alcanzado el tiempo de inactividad
      if (difference >= inactivityTimeout) {
        print(
            'Sesión cerrada por inactividad después de ${inactivityTimeout.inMinutes} minutos');
        _forceLogout();
        timer.cancel();
      }
    });
  }

  void _showWarningDialog(int secondsRemaining) {
    if (_isShowingWarning) return;

    // Usar el navigatorKey global para obtener el contexto
    final context = navigatorKey.currentContext;
    if (context == null) {
      print('No se puede mostrar el diálogo: contexto no disponible');
      return;
    }

    _isShowingWarning = true;

    int countdown = secondsRemaining;
    final countdownNotifier = ValueNotifier<int>(countdown);

    _warningTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      countdown--;
      countdownNotifier.value = countdown;

      if (countdown <= 0) {
        timer.cancel();
        Navigator.of(context, rootNavigator: true).pop(); // Cerrar diálogo
        _forceLogout(); // Cerrar sesión
      }
    });

    // Usar el context del navigator global
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => WillPopScope(
        onWillPop: () async => false, // Prevenir cierre con botón atrás
        child: AlertDialog(
          title: const Text('Advertencia de cierre de sesión'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Su sesión está a punto de expirar por inactividad.'),
              const SizedBox(height: 16),
              ValueListenableBuilder<int>(
                valueListenable: countdownNotifier,
                builder: (context, value, child) {
                  return Column(
                    children: [
                      Text(
                        'La sesión se cerrará en:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF49B8E2),
                        ),
                        child: Center(
                          child: Text(
                            '$value',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _warningTimer?.cancel();
                _isShowingWarning = false;
                Navigator.of(dialogContext).pop();
                logout();

                _navigateToLogin();
              },
              child: const Text('Cerrar sesión ahora',
                  style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                _warningTimer?.cancel();
                _isShowingWarning = false;
                resetInactivityTimer();
                Navigator.of(dialogContext).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF49B8E2),
              ),
              child: const Text('Continuar sesión',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToLogin() {
    if (navigatorKey.currentContext != null) {
      Navigator.pushAndRemoveUntil(
        navigatorKey.currentContext!,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _forceLogout() {
    _warningTimer?.cancel();
    _isShowingWarning = false;
    logout();

    if (navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        const SnackBar(
          content: Text('Sesión cerrada por inactividad'),
          backgroundColor: Colors.red,
        ),
      );

      _navigateToLogin();
    }
  }

  // Para pantalla de login
  void startLoginScreenTimer(BuildContext context) {
    _loginScreenTimer?.cancel();

    _loginScreenTimer = Timer(loginScreenTimeout, () {
      print(
          'Cerrando aplicación después de ${loginScreenTimeout.inMinutes} minutos de inactividad en login');
      _closeApp();
    });
  }

  void resetLoginScreenTimer(BuildContext context) {
    startLoginScreenTimer(context);
  }

  void _closeApp() {
    // Cerrar la aplicación
    try {
      SystemNavigator.pop();
    } catch (e) {
      print('Error al cerrar la aplicación: $e');
    }
  }

  void resetInactivityTimer() {
    if (isAuthenticated) {
      // Implementar throttling - limitar a una actualización cada 5 segundos máximo
      final now = DateTime.now();
      if (now.difference(_lastResetTime) > const Duration(seconds: 5)) {
        _lastActivityTime = now;
        _lastResetTime = now;

        // Si hay diálogo de advertencia abierto, cerrarlo
        if (_isShowingWarning && navigatorKey.currentContext != null) {
          _warningTimer?.cancel();
          _isShowingWarning = false;
          Navigator.of(navigatorKey.currentContext!, rootNavigator: true).pop();
        }

        print('Actividad detectada - Timer reiniciado');
      }
    }
  }

  Future<bool> login(String username, String password) async {
    // Evitar múltiples intentos de login simultáneos
    if (_isProcessingLogin) {
      print(
          'Ya hay un proceso de login en curso, ignorando la nueva solicitud');
      return false;
    }

    _isProcessingLogin = true;

    try {
      final response = await _dio.post('/auth/login', data: {
        'username': username,
        'password': password,
      });

      if (response.statusCode == 200 && response.data['success']) {
        final userData = response.data['user'];

        // Asignar rol basado en pmus_funcion
        final int funcion = userData['pmus_funcion'] ?? 1;
        List<String> roles = [];

        // Asignar roles basados en el campo funcion
        if (funcion == 1) {
          roles = ['admin'];
        } else if (funcion == 4) {
          roles = ['monitoreador'];
        } else {
          roles = ['usuario'];
        }

        // Crear el modelo de usuario con los roles asignados
        _currentUser = UserModel(
          id: userData['pmus_id'] ?? 0,
          codigo: userData['pmus_codigo'] ?? 0,
          username: userData['pmus_usuario'] ?? '',
          name: userData['pmus_usuario'] ??
              '', // Usar usuario como nombre si no hay otro campo
          funcion: funcion,
          roles: roles,
        );

        // Actualizar la configuración si se incluye en la respuesta
        if (response.data.containsKey('config')) {
          await _apiConfig.updateFromServerResponse(response.data['config']);
        }

        _lastActivityTime = DateTime.now();
        _loginScreenTimer?.cancel(); // Cancelar el timer de login screen
        _startInactivityTimer(null);

        // Notificar a los listeners después de establecer el usuario
        notifyListeners();

        // Pequeña pausa para asegurar que el cambio de estado se propague
        await Future.delayed(const Duration(milliseconds: 100));

        _isProcessingLogin = false;
        return true;
      }

      _isProcessingLogin = false;
      return false;
    } catch (e) {
      print('Error en login: $e');
      _isProcessingLogin = false;
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    _inactivityTimer?.cancel();
    _warningTimer?.cancel();
    _isShowingWarning = false;
    _inactivityTimer = null;
    _warningTimer = null;

    // Asegurar que los listeners se notifiquen del cambio
    notifyListeners();
  }

  void checkActivity(BuildContext context) {
    if (isAuthenticated) {
      resetInactivityTimer();
    } else {
      // Si está en la pantalla de login
      resetLoginScreenTimer(context);
    }
  }

  // Método para obtener el ID del usuario actual o un valor por defecto
  int getCurrentUserId() {
    return _currentUser?.id ?? 0;
  }

  // Método para verificar si el usuario actual creó un monitoreo
  bool isOwnerOfMonitoreo(int createdById) {
    return getCurrentUserId() == createdById;
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _warningTimer?.cancel();
    _loginScreenTimer?.cancel();
    _apiConfig.removeListener(_updateDioBaseUrl);
    super.dispose();
  }
}
