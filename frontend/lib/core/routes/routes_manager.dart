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

  /// Obtener rutas nombradas para la aplicación
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      login: (context) => const LoginScreen(),
      home: (context) => _protectedRoute(
            const HomeScreen(nombreUsuario: '', empresa: 'Costa Farms LLC'),
            canAccessHome,
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

  /// Función para verificar si un usuario puede acceder a la pantalla Home
  static bool canAccessHome(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    // Si el usuario no está autenticado, no puede acceder
    if (!authService.isAuthenticated) {
      return false;
    }

    // Si el usuario es monitoreador y no es admin, no puede acceder al Home
    if (authService.isMonitoreador && !authService.isAdmin) {
      return false;
    }

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
      // Si no tiene acceso, redirigir a la pantalla apropiada
      if (authService.isMonitoreador) {
        // Envolver en Scaffold para evitar problemas de contexto
        return Scaffold(
          body: MonitoreoScreen(
            onEditModeChanged: (_) {}, // Callback vacío
          ),
        );
      }

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
            // Si ya está autenticado y trata de ir a login, redirigir según rol
            if (authService.isAuthenticated) {
              // Redirigir basado en el rol
              if (authService.isMonitoreador && !authService.isAdmin) {
                return Scaffold(
                  body: MonitoreoScreen(
                    onEditModeChanged: (_) {}, // Callback vacío
                  ),
                );
              } else {
                return HomeScreen(
                  nombreUsuario: authService.currentUser?.username ?? '',
                  empresa: 'Costa Farms LLC',
                );
              }
            }
            return const LoginScreen();
          case home:
            if (!authService.isAuthenticated) {
              return const LoginScreen();
            }

            if (authService.isMonitoreador && !authService.isAdmin) {
              // Los monitoreadores no pueden acceder al Home
              return Scaffold(
                body: MonitoreoScreen(
                  onEditModeChanged: (_) {}, // Callback vacío
                ),
              );
            }
            return HomeScreen(
              nombreUsuario: authService.currentUser?.username ?? '',
              empresa: 'Costa Farms LLC',
            );
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

            return authService.isMonitoreador && !authService.isAdmin
                ? Scaffold(
                    body: MonitoreoScreen(
                      onEditModeChanged: (_) {}, // Callback vacío
                    ),
                  )
                : HomeScreen(
                    nombreUsuario: authService.currentUser?.username ?? '',
                    empresa: 'Costa Farms LLC',
                  );
        }
      },
    );
  }
}
