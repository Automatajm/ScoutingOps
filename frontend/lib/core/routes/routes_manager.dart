import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/datasources/auth_service.dart';
import '../../presentation/pages/auth/login_screen.dart';
import '../../presentation/pages/home/home_screen.dart';
import '../../presentation/monitoring/monitoreo_screen.dart';

/// Clase para gestionar las rutas de la aplicación con control de acceso por roles
class RoutesManager {
  // Definición de rutas nombradas
  static const String login = '/login';
  static const String home = '/home';
  static const String monitoreo = '/monitoreo';

  /// ✅ NUEVO: Detectar si es dispositivo móvil basado en ancho de pantalla
  static bool _isMobileDevice(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth < 600; // Menos de 600px se considera móvil
  }

  /// ✅ NUEVO: Determinar la pantalla apropiada según rol y dispositivo
  static Widget _getAppropriateScreen(
      BuildContext context, AuthService authService) {
    final bool isMobile = _isMobileDevice(context);

    // Si es admin en móvil, enviarlo a MonitoreoScreen SIN filtros
    if (authService.isAdmin && isMobile) {
      return Scaffold(
        body: MonitoreoScreen(
          onEditModeChanged: (_) {}, // Callback vacío
        ),
      );
    }

    // Si es monitoreador (no admin), siempre a MonitoreoScreen CON filtros
    if (authService.isMonitoreador && !authService.isAdmin) {
      return Scaffold(
        body: MonitoreoScreen(
          onEditModeChanged: (_) {}, // Callback vacío
        ),
      );
    }

    // Para admins en desktop/tablet, ir a HomeScreen
    return HomeScreen(
      nombreUsuario: authService.currentUser?.username ?? '',
      empresa: 'Costa Farms LLC',
    );
  }

  /// Obtener rutas nombradas para la aplicación
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      login: (context) => const LoginScreen(),
      home: (context) => _protectedRoute(
            // ✅ MODIFICADO: Usar función que decide la pantalla apropiada
            Builder(builder: (context) {
              final authService =
                  Provider.of<AuthService>(context, listen: false);
              return _getAppropriateScreen(context, authService);
            }),
            canAccessApp, // ✅ RENOMBRADO: de canAccessHome a canAccessApp
            context,
          ),
      monitoreo: (context) => Scaffold(
            body: MonitoreoScreen(
              onEditModeChanged: (_) {}, // Callback vacío
            ),
          ),
    };
  }

  /// Definir la ruta inicial basada en el estado de autenticación
  static String getInitialRoute(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    // Siempre comenzar en la pantalla de login para evitar problemas
    // de estado de autenticación inicial
    return login;
  }

  /// ✅ MODIFICADO: Función para verificar si un usuario puede acceder a la app
  static bool canAccessApp(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    // Si el usuario no está autenticado, no puede acceder
    if (!authService.isAuthenticated) {
      return false;
    }

    // ✅ CAMBIO IMPORTANTE: Todos los usuarios autenticados pueden acceder
    // La diferencia será QUÉ pantalla ven (Home vs Monitoreo)
    return true;
  }

  /// Proteger una ruta con verificación de acceso
  static Widget _protectedRoute(
    Widget destination,
    bool Function(BuildContext) accessCheck,
    BuildContext context,
  ) {
    // Verificar autenticación primero
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) {
      return const LoginScreen();
    }

    // Luego verificar acceso específico
    if (!accessCheck(context)) {
      return const LoginScreen();
    }

    return destination;
  }

  /// Middleware para manejo de rutas que requieren autenticación
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute(
      settings: settings,
      builder: (context) {
        final authService = Provider.of<AuthService>(context, listen: false);

        // Si no está autenticado y no es la pantalla de login, redirigir a login
        if (!authService.isAuthenticated && settings.name != login) {
          return const LoginScreen();
        }

        // Manejar las rutas específicas
        switch (settings.name) {
          case login:
            // Si ya está autenticado y trata de ir a login, redirigir según rol y dispositivo
            if (authService.isAuthenticated) {
              return _getAppropriateScreen(context, authService);
            }
            return const LoginScreen();

          case home:
            if (!authService.isAuthenticated) {
              return const LoginScreen();
            }
            // ✅ MODIFICADO: Usar la función que decide la pantalla apropiada
            return _getAppropriateScreen(context, authService);

          case monitoreo:
            if (!authService.isAuthenticated) {
              return const LoginScreen();
            }
            return Scaffold(
              body: MonitoreoScreen(
                onEditModeChanged: (_) {}, // Callback vacío
              ),
            );

          default:
            // Ruta por defecto
            if (!authService.isAuthenticated) {
              return const LoginScreen();
            }
            // ✅ MODIFICADO: Usar la función que decide la pantalla apropiada
            return _getAppropriateScreen(context, authService);
        }
      },
    );
  }
}
