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
    return Material(
      child: Overlay(
        initialEntries: [
          OverlayEntry(
            builder: (context) => child,
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
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
    // Registrar observer para detectar cambios en la app
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Iniciar temporizador de pantalla de login
      _authService = Provider.of<AuthService>(context, listen: false);
      _apiConfig = Provider.of<ApiConfig>(context, listen: false);
      _authService.startLoginScreenTimer(context);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authService = Provider.of<AuthService>(context, listen: false);
    _apiConfig = Provider.of<ApiConfig>(context, listen: false);
  }

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    _userFocusNode.dispose();
    _passwordFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ConfigurationScreen(
          apiConfig: _apiConfig,
          onConfigSuccess: () {
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
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await _authService.login(
        _userController.text,
        _passwordController.text,
      );

      if (mounted) {
        if (success) {
          // Navegación mejorada - usar pushReplacementNamed para evitar capas superpuestas
          _navigateBasedOnRole(_authService);
        } else {
          setState(() {
            _errorMessage = 'Usuario o contraseña incorrectos';
          });
        }
      }
    } catch (e) {
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
    // Asegurar que el Navigator global se use para la navegación
    final navigator = Navigator.of(context);

    if (authService.isMonitoreador && !authService.isAdmin) {
      // Usar pushNamedAndRemoveUntil para limpiar la pila de navegación
      navigator.pushNamedAndRemoveUntil(
        RoutesManager.monitoreo,
        (route) => false,
      );
    } else {
      // Para otros roles, ir al Home normal
      navigator.pushNamedAndRemoveUntil(
        RoutesManager.home,
        (route) => false,
      );
    }
  }

  void _onSubmit(BuildContext context) {
    if (_userController.text.isEmpty) {
      FocusScope.of(context).requestFocus(_userFocusNode);
    } else if (_passwordController.text.isEmpty) {
      FocusScope.of(context).requestFocus(_passwordFocusNode);
    } else {
      _handleLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final screenWidth = mediaQuery.size.width;
    final isKeyboardOpen = keyboardHeight > 0;
    final isMobile = screenWidth < 600;
    
    return OverlayLoginWrapper(
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: (isKeyboardOpen && isMobile) ? 30 : 56,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings, color: Color(0xFF49B8E2)),
              onPressed: _showConfigurationScreen,
              tooltip: 'Configurar servidor',
            ),
          ],
        ),
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
                          FocusScope.of(context).requestFocus(_passwordFocusNode);
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
                            borderSide: const BorderSide(color: Color(0xFF49B8E2)),
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

                      // Password Input - FORZANDO REBUILD COMPLETO
                      TextFormField(
                        key: ValueKey(_obscurePassword), // ESTO FUERZA REBUILD
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
                          prefixIcon: const Icon(
                            Icons.lock,
                            color: Color(0xFF49B8E2),
                          ),
                          suffixIcon: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: const Color(0xFF49B8E2),
                                  size: 20,
                                ),
                              ),
                            ),
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
                            borderSide: const BorderSide(color: Color(0xFF49B8E2)),
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
                        onPressed: _isLoading ? null : () {
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
                              },
                              child: Text(
                                'Contraseña',
                                style: TextStyle(
                                  color: const Color(0xFF49B8E2),
                                  fontSize: isMobile ? 12 : 14,
                                ),
                              ),
                            ),
                            const Text('|', style: TextStyle(color: Colors.grey)),
                            TextButton(
                              onPressed: () {
                                _handleUserActivity();
                              },
                              child: Text(
                                'Contacto',
                                style: TextStyle(
                                  color: const Color(0xFF49B8E2),
                                  fontSize: isMobile ? 12 : 14,
                                ),
                              ),
                            ),
                            const Text('|', style: TextStyle(color: Colors.grey)),
                            TextButton(
                              onPressed: () {
                                _handleUserActivity();
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

                        // Mostrar la URL del servidor actual
                        Consumer<ApiConfig>(
                          builder: (context, apiConfig, child) {
                            return Padding(
                              padding: EdgeInsets.only(top: isMobile ? 8 : 16),
                              child: Text(
                                'Servidor: ${apiConfig.apiUrl.replaceAll('/api', '')}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: isMobile ? 10 : 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
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