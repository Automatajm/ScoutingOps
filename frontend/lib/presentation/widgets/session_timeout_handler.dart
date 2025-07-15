import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/datasources/auth_service.dart';
import '../pages/auth/login_screen.dart';

class SessionTimeoutHandler extends StatefulWidget {
  final Widget child;
  final AuthService authService;

  const SessionTimeoutHandler({
    Key? key,
    required this.child,
    required this.authService,
  }) : super(key: key);

  @override
  State<SessionTimeoutHandler> createState() => _SessionTimeoutHandlerState();
}

class _SessionTimeoutHandlerState extends State<SessionTimeoutHandler>
    with WidgetsBindingObserver {
  // Variable para controlar el throttling de eventos
  DateTime _lastActivityTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Registrar observer para detectar cambios en el estado de la aplicación
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Remover observer al destruir el widget
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Detectar cuando la app vuelve al primer plano
    if (state == AppLifecycleState.resumed) {
      _handleUserActivity();
    }
  }

  void _handleUserActivity([_]) {
    // Implementar throttling para evitar demasiadas actualizaciones
    final now = DateTime.now();
    if (now.difference(_lastActivityTime) > const Duration(seconds: 2)) {
      _lastActivityTime = now;

      if (mounted) {
        final context = AuthService.navigatorKey.currentContext ?? this.context;
        widget.authService.checkActivity(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handleUserActivity,
      // No usar onPointerMove para reducir la cantidad de eventos
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}

/// Navegador que redirecciona a login cuando el servicio de autenticación lo indica
class AuthNavigator extends StatefulWidget {
  final Widget child;
  final AuthService authService;

  const AuthNavigator({
    Key? key,
    required this.child,
    required this.authService,
  }) : super(key: key);

  @override
  State<AuthNavigator> createState() => _AuthNavigatorState();
}

class _AuthNavigatorState extends State<AuthNavigator> {
  @override
  void initState() {
    super.initState();
    // Suscribirse a cambios en el estado de autenticación
    widget.authService.addListener(_checkAuthentication);
  }

  @override
  void dispose() {
    // Cancelar suscripción al destruir el widget
    widget.authService.removeListener(_checkAuthentication);
    super.dispose();
  }

  void _checkAuthentication() {
    // Verificar si el usuario ya no está autenticado
    if (!widget.authService.isAuthenticated && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final route = ModalRoute.of(context)?.settings.name;
        if (route != '/login') {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si no está autenticado, ir a login
    if (!widget.authService.isAuthenticated) {
      return const LoginScreen();
    }

    // Si es monitoreador (y no admin), verificar acceso a rutas restringidas
    final route = ModalRoute.of(context)?.settings.name;

    if (widget.authService.isMonitoreador &&
        !widget.authService.isAdmin &&
        route != '/monitoreo' &&
        route != '/login') {
      // Prevenir acceso a otras rutas
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ModalRoute.of(context)?.settings.name != '/monitoreo') {
          Navigator.pushReplacementNamed(context, '/monitoreo');
        }
      });
    }

    return widget.child;
  }
}
