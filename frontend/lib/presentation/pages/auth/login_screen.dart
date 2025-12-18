import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../data/datasources/auth_service.dart';
import '../../../core/routes/routes_manager.dart';
import '../../../core/config/flavor_config.dart';
import 'configuration_screen.dart';

// Widget wrapper personalizado con Overlay para resolver el problema de No Overlay widget found
class OverlayLoginWrapper extends StatelessWidget {
  final Widget child;

  const OverlayLoginWrapper({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    debugPrint('🎨 [OverlayLoginWrapper.build] Construyendo wrapper...');
    return Material(
      child: Overlay(
        initialEntries: [
          OverlayEntry(
            builder: (context) {
              debugPrint(
                  '🎨 [OverlayLoginWrapper.OverlayEntry] Construyendo entry...');
              return child;
            },
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() {
    debugPrint('🏗️ [LoginScreen] Creando state...');
    return _LoginScreenState();
  }
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  final _userFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  late AuthService _authService;
  late ApiConfig _apiConfig;

  // Variable para throttling
  DateTime _lastUserActivityTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    debugPrint('🔐 [LoginScreen.initState] Inicializando LoginScreen...');

    // Registrar observer para detectar cambios en la app
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('🔐 [LoginScreen.postFrameCallback] Ejecutando callback...');

      try {
        // Iniciar temporizador de pantalla de login
        _authService = Provider.of<AuthService>(context, listen: false);
        _apiConfig = Provider.of<ApiConfig>(context, listen: false);

        debugPrint(
            '🔐 [LoginScreen] AuthService obtenido: ${_authService != null}');
        debugPrint(
            '🔐 [LoginScreen] ApiConfig obtenido: ${_apiConfig != null}');

        _authService.startLoginScreenTimer(context);

        debugPrint('✅ [LoginScreen] Inicialización completa');
      } catch (e) {
        debugPrint('❌ [LoginScreen] Error en postFrameCallback: $e');
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint(
        '🔄 [LoginScreen.didChangeDependencies] Dependencias cambiadas...');

    try {
      _authService = Provider.of<AuthService>(context, listen: false);
      _apiConfig = Provider.of<ApiConfig>(context, listen: false);
      debugPrint(
          '✅ [LoginScreen] Providers actualizados en didChangeDependencies');
    } catch (e) {
      debugPrint('❌ [LoginScreen] Error obteniendo providers: $e');
    }
  }

  @override
  void dispose() {
    debugPrint('🗑️ [LoginScreen.dispose] Limpiando recursos...');
    _userController.dispose();
    _passwordController.dispose();
    _userFocusNode.dispose();
    _passwordFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('🔄 [LoginScreen] App lifecycle: $state');
    // Detectar cuando la app vuelve al primer plano
    if (state == AppLifecycleState.resumed) {
      _authService.resetLoginScreenTimer(context);
    }
  }

  void _handleUserActivity() {
    // Implementar throttling para no llamar demasiado a resetLoginScreenTimer
    final now = DateTime.now();
    if (now.difference(_lastUserActivityTime) > const Duration(seconds: 5)) {
      _lastUserActivityTime = now;
      _authService.resetLoginScreenTimer(context);
    }
  }

  void _showConfigurationScreen() {
    debugPrint('⚙️ [LoginScreen] Abriendo ConfigurationScreen...');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ConfigurationScreen(
          apiConfig: _apiConfig,
          onConfigSuccess: () {
            debugPrint('✅ [LoginScreen] Configuración guardada exitosamente');
            // Simplemente volver al login
            Navigator.of(context).pop();
            // Mostrar mensaje de confirmación
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Configuración guardada correctamente'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    debugPrint('🔑 [LoginScreen] Intentando login...');

    if (!_formKey.currentState!.validate()) {
      debugPrint('❌ [LoginScreen] Validación de formulario falló');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('🔑 [LoginScreen] Llamando authService.login...');
      final success = await _authService.login(
        _userController.text,
        _passwordController.text,
      );

      debugPrint('🔑 [LoginScreen] Login result: $success');

      if (mounted) {
        if (success) {
          debugPrint('✅ [LoginScreen] Login exitoso, navegando...');
          // Navegación mejorada - usar pushReplacementNamed para evitar capas superpuestas
          _navigateBasedOnRole(_authService);
        } else {
          debugPrint('❌ [LoginScreen] Login falló - credenciales incorrectas');
          setState(() {
            _errorMessage = 'Usuario o contraseña incorrectos';
          });
        }
      }
    } catch (e) {
      debugPrint('❌ [LoginScreen] Error en login: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al iniciar sesión: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Método actualizado para redirigir según el rol del usuario
  void _navigateBasedOnRole(AuthService authService) {
    debugPrint('🧭 [LoginScreen] Navegando basado en rol...');
    debugPrint('   - isAdmin: ${authService.isAdmin}');
    debugPrint('   - isMonitoreador: ${authService.isMonitoreador}');

    // ✅ NUEVO: Actualizar contexto en AuthService para detección de dispositivo
    authService.updateContext(context);

    // Asegurar que el Navigator global se use para la navegación
    final navigator = Navigator.of(context);

    // ✅ MODIFICADO: Verificar si es admin en móvil para enviar a monitoreo
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    debugPrint('   - screenWidth: $screenWidth');
    debugPrint('   - isMobile: $isMobile');

    if (authService.isAdmin && isMobile) {
      debugPrint('🎯 [LoginScreen] Admin en móvil → Monitoreo');
      // Admin en móvil: ir a MonitoreoScreen (sin filtros)
      navigator.pushNamedAndRemoveUntil(
        RoutesManager.monitoreo,
        (route) => false,
      );
    } else if (authService.isMonitoreador && !authService.isAdmin) {
      debugPrint('🎯 [LoginScreen] Monitoreador → Monitoreo');
      // Monitoreador normal: ir a MonitoreoScreen (con filtros)
      navigator.pushNamedAndRemoveUntil(
        RoutesManager.monitoreo,
        (route) => false,
      );
    } else {
      debugPrint('🎯 [LoginScreen] Usuario normal/Admin desktop → Home');
      // Admin en desktop o usuarios normales: ir al Home
      navigator.pushNamedAndRemoveUntil(
        RoutesManager.home,
        (route) => false,
      );
    }
  }

  void _onSubmit(BuildContext context) {
    debugPrint('📝 [LoginScreen] Form submitted');
    if (_userController.text.isEmpty) {
      FocusScope.of(context).requestFocus(_userFocusNode);
    } else if (_passwordController.text.isEmpty) {
      FocusScope.of(context).requestFocus(_passwordFocusNode);
    } else {
      _handleLogin();
    }
  }

  // ✅ CORREGIDO: Función para alternar visibilidad de contraseña
  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
    _handleUserActivity();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🎨 [LoginScreen.build] Construyendo UI...');

    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final screenWidth = mediaQuery.size.width;
    final isKeyboardOpen = keyboardHeight > 0;
    final isMobile = screenWidth < 600;

    debugPrint('   - screenWidth: $screenWidth');
    debugPrint('   - isMobile: $isMobile');
    debugPrint('   - isKeyboardOpen: $isKeyboardOpen');

    return OverlayLoginWrapper(
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: Listener(
          onPointerDown: (_) => _handleUserActivity(),
          behavior: HitTestBehavior.translucent,
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo y título - más simple
                      if (!isKeyboardOpen || !isMobile) ...[
                        Image.asset(
                          'assets/images/logo.png',
                          width: isMobile ? 80 : 120,
                          height: isMobile ? 80 : 120,
                        ),
                        SizedBox(height: isMobile ? 8 : 16),
                        Text(
                          'Costa Analytics',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 18 : 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF49B8E2),
                          ),
                        ),
                        SizedBox(height: isMobile ? 20 : 32),
                      ],

                      // Título compacto para móvil con teclado
                      if (isKeyboardOpen && isMobile) ...[
                        const Text(
                          'Costa Analytics',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF49B8E2),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Error Message
                      if (_errorMessage != null)
                        Container(
                          padding: EdgeInsets.all(isMobile ? 8 : 12),
                          margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.w500,
                              fontSize: isMobile ? 12 : 14,
                            ),
                          ),
                        ),

                      // Username Input
                      TextFormField(
                        controller: _userController,
                        focusNode: _userFocusNode,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.next,
                        onTap: _handleUserActivity,
                        onChanged: (_) => _handleUserActivity(),
                        onFieldSubmitted: (_) {
                          FocusScope.of(context)
                              .requestFocus(_passwordFocusNode);
                          _handleUserActivity();
                        },
                        decoration: InputDecoration(
                          labelText: 'Usuario',
                          labelStyle: TextStyle(fontSize: isMobile ? 13 : 14),
                          prefixIcon: Icon(
                            Icons.person,
                            color: const Color(0xFF49B8E2),
                            size: isMobile ? 18 : 20,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 16,
                            vertical: isMobile ? 8 : 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFF49B8E2)),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingrese su usuario';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: isMobile ? 12 : 16),

                      // Password Input
                      TextFormField(
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        enabled: !_isLoading,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onTap: _handleUserActivity,
                        onChanged: (_) => _handleUserActivity(),
                        onFieldSubmitted: (_) {
                          _onSubmit(context);
                          _handleUserActivity();
                        },
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          labelStyle: TextStyle(fontSize: isMobile ? 13 : 14),
                          prefixIcon: Icon(
                            Icons.lock,
                            color: const Color(0xFF49B8E2),
                            size: isMobile ? 18 : 20,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: const Color(0xFF49B8E2),
                              size: isMobile ? 18 : 20,
                            ),
                            onPressed: _togglePasswordVisibility,
                            splashRadius: 20,
                            tooltip: _obscurePassword
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 16,
                            vertical: isMobile ? 8 : 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFF49B8E2)),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingrese su contraseña';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: isMobile ? 16 : 24),

                      // Login Button
                      ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                _onSubmit(context);
                                _handleUserActivity();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF49B8E2),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 12 : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: isMobile ? 18 : 24,
                                height: isMobile ? 18 : 24,
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Iniciar sesión',
                                style: TextStyle(
                                  fontSize: isMobile ? 14 : 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),

                      // Footer Links - Solo mostrar cuando no hay teclado en móvil
                      if (!isKeyboardOpen || !isMobile) ...[
                        SizedBox(height: isMobile ? 12 : 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () {
                                _handleUserActivity();
                                // TODO: Implementar recuperación de contraseña
                              },
                              child: Text(
                                'Contraseña',
                                style: TextStyle(
                                  color: const Color(0xFF49B8E2),
                                  fontSize: isMobile ? 12 : 14,
                                ),
                              ),
                            ),
                            const Text('|',
                                style: TextStyle(color: Colors.grey)),
                            Tooltip(
                              message:
                                  'jmendoza@costanursery.com | 809-722-4957 | DR - Helpdesk',
                              textStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade800,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: TextButton(
                                onPressed: () {
                                  _handleUserActivity();
                                  // TODO: Implementar información de contacto
                                },
                                child: Text(
                                  'Contacto',
                                  style: TextStyle(
                                    color: const Color(0xFF49B8E2),
                                    fontSize: isMobile ? 12 : 14,
                                  ),
                                ),
                              ),
                            ),
                            const Text('|',
                                style: TextStyle(color: Colors.grey)),
                            TextButton(
                              onPressed: () {
                                _handleUserActivity();
                                // TODO: Implementar términos y condiciones
                              },
                              child: Text(
                                'Términos',
                                style: TextStyle(
                                  color: const Color(0xFF49B8E2),
                                  fontSize: isMobile ? 12 : 14,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Acceso discreto a configuración
                        SizedBox(height: isMobile ? 8 : 12),
                        GestureDetector(
                          onTap: () {
                            _showConfigurationScreen();
                          },
                          child: Container(
                            height: 20,
                            color: Colors.transparent,
                            child: Center(
                              child: Container(
                                width: 20,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
