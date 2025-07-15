import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'data/datasources/auth_service.dart';
import 'services/intranet_service.dart';
import 'services/service_provider.dart';
import 'presentation/widgets/session_timeout_handler.dart';
import 'core/routes/routes_manager.dart';
import 'core/config/flavor_config.dart';
import 'presentation/pages/auth/configuration_screen.dart';

// Clase de inicialización de la aplicación
class AppInitializer {
  static OverlayState? get overlayState =>
      AuthService.navigatorKey.currentState?.overlay;
}

// Navegador de autenticación
class AuthNavigator extends StatelessWidget {
  final AuthService authService;
  final Widget child;

  const AuthNavigator({
    Key? key,
    required this.authService,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

// Clase de inicio de la aplicación
class AppStartup extends StatefulWidget {
  final Widget child;
  final ApiConfig apiConfig;

  const AppStartup({
    Key? key,
    required this.child,
    required this.apiConfig,
  }) : super(key: key);

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  bool _isInitializing = true;
  bool _needsConfiguration = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      if (mounted) {
        Logger.debug('Iniciando verificación de configuración...');
      }

      // IMPORTANTE: Verificar si ya tenemos una configuración válida
      final isConfigured = widget.apiConfig.isConfigured;
      final hasValidUrls = widget.apiConfig.baseUrl.isNotEmpty &&
          widget.apiConfig.apiUrl.isNotEmpty;

      if (mounted) {
        Logger.debug('Estado de configuración', {
          'baseUrl': widget.apiConfig.baseUrl,
          'apiUrl': widget.apiConfig.apiUrl,
          'isConfigured': isConfigured,
          'hasValidUrls': hasValidUrls,
          'environment': widget.apiConfig.environment,
          'version': widget.apiConfig.version,
        });
      }

      final needsConfig = !isConfigured || !hasValidUrls;

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _needsConfiguration = needsConfig;
        });

        Logger.info(
            'Inicialización completada', {'needsConfiguration': needsConfig});
      }
    } catch (e) {
      Logger.error('Error inicializando la app', e);
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _needsConfiguration = true;
        });
      }
    }
  }

  void _refreshConfigurationState() {
    if (mounted) {
      final isConfigured = widget.apiConfig.isConfigured;
      final hasValidUrls = widget.apiConfig.baseUrl.isNotEmpty &&
          widget.apiConfig.apiUrl.isNotEmpty;

      Logger.debug('Refrescando estado de configuración', {
        'isConfigured': isConfigured,
        'hasValidUrls': hasValidUrls,
      });

      setState(() {
        _needsConfiguration = !isConfigured || !hasValidUrls;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // SPLASH SCREEN
    if (_isInitializing) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF49B8E2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.pest_control,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(
                  color: Color(0xFF49B8E2),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Pest Control',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF49B8E2),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Costa Analytics',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Inicializando aplicación...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // PANTALLA DE CONFIGURACIÓN
    if (_needsConfiguration) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF49B8E2),
            primary: const Color(0xFF49B8E2),
          ),
          useMaterial3: true,
        ),
        home: ConfigurationScreen(
          apiConfig: widget.apiConfig,
          onConfigSuccess: () {
            Logger.info('Configuración completada exitosamente', {
              'baseUrl': widget.apiConfig.baseUrl,
              'apiUrl': widget.apiConfig.apiUrl,
              'isConfigured': widget.apiConfig.isConfigured,
            });
            _refreshConfigurationState();
          },
        ),
      );
    }

    // APP PRINCIPAL
    Logger.info('Lanzando app principal con configuración válida');
    return widget.child;
  }
}

void main() async {
  debugPrint('🚀 Iniciando aplicación Pest Control...');

  // Asegurar inicialización de Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar orientación
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    // PASO 1: Cargar variables de entorno
    debugPrint('🔧 Cargando variables de entorno...');
    try {
      await dotenv.load(fileName: '.env.development');
    } catch (e) {
      debugPrint('⚠️ No se pudo cargar .env.development: $e');
    }

    // PASO 2: Inicializar FlavorConfig
    debugPrint('🔧 Inicializando FlavorConfig...');
    await FlavorConfig.initialize(Flavor.development);

    // PASO 3: Obtener ApiConfig
    debugPrint('🔧 Obteniendo instancia de ApiConfig...');
    final apiConfig = FlavorConfig.apiConfig;

    if (kDebugMode) {
      debugPrint('📊 Estado inicial de ApiConfig: '
          'baseUrl: ${apiConfig.baseUrl}, '
          'apiUrl: ${apiConfig.apiUrl}, '
          'isConfigured: ${apiConfig.isConfigured}, '
          'environment: ${apiConfig.environment}');
    }

    // PASO 4: Inicializar servicio de intranet
    debugPrint('🔧 Inicializando servicio de intranet...');
    final intranetService = IntranetService();
    await intranetService.initialize();

    // PASO 5: Configurar manejador de errores global
    FlutterError.onError = (FlutterErrorDetails details) {
      if (FlavorConfig.isProduction) {
        debugPrint(
            '❌ CRITICAL ERROR [REF-${DateTime.now().millisecondsSinceEpoch}]');
      } else {
        debugPrint('❌ ERROR: ${details.exception}');
        if (kDebugMode) {
          debugPrint('Stack trace: ${details.stack}');
        }
      }
      FlutterError.presentError(details);
    };

    debugPrint('✅ Inicialización completada, lanzando app...');

    // PASO 6: Lanzar la aplicación
    runApp(
      AppStartup(
        apiConfig: apiConfig,
        child: ServiceProvider(
          apiConfig: apiConfig,
          intranetService: intranetService,
          child: const MyApp(),
        ),
      ),
    );
  } catch (e, stackTrace) {
    if (FlavorConfig.isProduction) {
      debugPrint(
          '❌ STARTUP ERROR [REF-${DateTime.now().millisecondsSinceEpoch}]');
    } else {
      debugPrint('❌ Error crítico durante la inicialización: $e');
      if (kDebugMode) {
        debugPrint('Stack trace completo: $stackTrace');
      }
    }

    // App de emergencia
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.red.shade50,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Colors.red.shade600,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Error de Inicialización',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'La aplicación no pudo inicializarse correctamente. Por favor, reinicie la aplicación.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      SystemNavigator.pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Cerrar aplicación'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final intranetService =
            Provider.of<IntranetService>(context, listen: false);

        return MaterialApp(
          title: 'Pest Control - Costa Analytics',
          debugShowCheckedModeBanner: false,
          navigatorKey: AuthService.navigatorKey,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF49B8E2),
              primary: const Color(0xFF49B8E2),
            ),
            useMaterial3: true,
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: false,
              iconTheme: const IconThemeData(
                color: Color(0xFF49B8E2),
              ),
              titleTextStyle: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            textTheme: TextTheme(
              bodyLarge: TextStyle(color: Colors.grey.shade800),
              bodyMedium: TextStyle(color: Colors.grey.shade700),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF49B8E2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF49B8E2),
                  width: 2,
                ),
              ),
            ),
          ),
          builder: (context, child) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              AppInitializer.overlayState;
            });

            Widget wrappedChild = SessionTimeoutHandler(
              authService: authService,
              child: AuthNavigator(
                authService: authService,
                child: child ?? const SizedBox.shrink(),
              ),
            );

            final currentRouteName = ModalRoute.of(context)?.settings.name;
            final isLoginScreen = currentRouteName == RoutesManager.login ||
                currentRouteName == null;

            if (isLoginScreen) {
              return wrappedChild;
            }

            // Indicador de conectividad
            return Stack(
              children: [
                wrappedChild,
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: intranetService.isConnected,
                    builder: (context, isConnected, _) {
                      if (isConnected) return const SizedBox.shrink();

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            intranetService.refreshConnection();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Verificando conexión...'),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF49B8E2),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.red.shade300,
                                  width: 1,
                                ),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.wifi_off,
                                  size: 16,
                                  color: Colors.red.shade800,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Sin conexión - Modo offline',
                                  style: TextStyle(
                                    color: Colors.red.shade800,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.refresh,
                                  size: 16,
                                  color: Colors.red.shade800,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
          initialRoute: RoutesManager.login,
          routes: RoutesManager.getRoutes(),
          onGenerateRoute: RoutesManager.onGenerateRoute,
        );
      },
    );
  }
}
