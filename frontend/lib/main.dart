// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'data/datasources/auth_service.dart';
import 'data/database/app_database.dart';
import 'services/intranet_service.dart';
import 'services/service_provider.dart';
import 'services/offline_database_service.dart';
import 'services/catalog_sync_service.dart';
import 'presentation/widgets/session_timeout_handler.dart';
import 'core/routes/routes_manager.dart';
import 'core/config/flavor_config.dart';
import 'presentation/pages/auth/configuration_screen.dart';
import 'services/lote_service.dart';

class AppInitializer {
  static OverlayState? get overlayState =>
      AuthService.navigatorKey.currentState?.overlay;
}

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
      final isConfigured = widget.apiConfig.isConfigured;
      final hasValidUrls = widget.apiConfig.baseUrl.isNotEmpty &&
          widget.apiConfig.apiUrl.isNotEmpty;

      final needsConfig = !isConfigured || !hasValidUrls;

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _needsConfiguration = needsConfig;
        });
      }
    } catch (e) {
      debugPrint('Error inicializando: $e');
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

      setState(() {
        _needsConfiguration = !isConfigured || !hasValidUrls;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  child: const Icon(Icons.pest_control,
                      size: 60, color: Colors.white),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(
                    color: Color(0xFF49B8E2), strokeWidth: 3),
                const SizedBox(height: 24),
                const Text('Pest Control',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF49B8E2))),
                const SizedBox(height: 8),
                const Text('Costa Analytics',
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 40),
                Text('Inicializando...',
                    style:
                        TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ),
      );
    }

    if (_needsConfiguration) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF49B8E2),
              primary: const Color(0xFF49B8E2)),
          useMaterial3: true,
        ),
        home: ConfigurationScreen(
          apiConfig: widget.apiConfig,
          onConfigSuccess: () => _refreshConfigurationState(),
        ),
      );
    }

    return widget.child;
  }
}

void main() async {
  debugPrint('🚀 Iniciando Pest Control...');
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    // Cargar .env
    try {
      await dotenv.load(fileName: '.env.development');
    } catch (e) {
      debugPrint('⚠️ No se pudo cargar .env: $e');
    }

    // Inicializar FlavorConfig
    await FlavorConfig.initialize(Flavor.development);
    final apiConfig = FlavorConfig.apiConfig;

    debugPrint(
        '📊 ApiConfig: baseUrl=${apiConfig.baseUrl}, apiUrl=${apiConfig.apiUrl}');

    // Inicializar IntranetService
    final intranetService = IntranetService();
    await intranetService.initialize();

    // Inicializar SQLite
    debugPrint('🔧 Inicializando SQLite...');
    final database = AppDatabase();
    final offlineDbService = OfflineDatabaseService(database);
    await offlineDbService.initialize();

    final dbStats = await offlineDbService.getStorageStats();
    debugPrint('📦 SQLite inicializado: $dbStats');

    LoteService().setDatabase(database);
    debugPrint('📦 LoteService configurado con SQLite');

    // Manejador de errores
    FlutterError.onError = (details) {
      debugPrint('❌ ERROR: ${details.exception}');
      FlutterError.presentError(details);
    };

    debugPrint('✅ Lanzando app...');

    runApp(
      AppStartup(
        apiConfig: apiConfig,
        child: ServiceProvider(
          apiConfig: apiConfig,
          intranetService: intranetService,
          database: database,
          offlineDbService: offlineDbService,
          child: const MyApp(),
        ),
      ),
    );
  } catch (e, stackTrace) {
    debugPrint('❌ Error crítico: $e');
    debugPrint('Stack: $stackTrace');

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
                  Icon(Icons.error_outline,
                      size: 80, color: Colors.red.shade600),
                  const SizedBox(height: 20),
                  Text('Error de Inicialización',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800)),
                  const SizedBox(height: 16),
                  Text(
                      'La aplicación no pudo inicializarse. Reinicie la aplicación.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 16, color: Colors.red.shade700)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => SystemNavigator.pop(),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white),
                    child: const Text('Cerrar'),
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _catalogSyncInitiated = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final intranetService =
            Provider.of<IntranetService>(context, listen: false);

        // Iniciar sincronización de catálogos una vez
        if (!_catalogSyncInitiated) {
          _catalogSyncInitiated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initCatalogSync(context);
          });
        }

        return MaterialApp(
          title: 'Pest Control - Costa Analytics',
          debugShowCheckedModeBanner: false,
          navigatorKey: AuthService.navigatorKey,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF49B8E2),
                primary: const Color(0xFF49B8E2)),
            useMaterial3: true,
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: false,
              iconTheme: const IconThemeData(color: Color(0xFF49B8E2)),
              titleTextStyle: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF49B8E2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
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
                  child: child ?? const SizedBox.shrink()),
            );

            final currentRouteName = ModalRoute.of(context)?.settings.name;
            final isLoginScreen = currentRouteName == RoutesManager.login ||
                currentRouteName == null;

            if (isLoginScreen) return wrappedChild;

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
                              const SnackBar(
                                content: Row(children: [
                                  SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white)),
                                  SizedBox(width: 12),
                                  Text('Verificando conexión...'),
                                ]),
                                backgroundColor: Color(0xFF49B8E2),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              border: Border(
                                  bottom: BorderSide(
                                      color: Colors.red.shade300, width: 1)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.wifi_off,
                                    size: 16, color: Colors.red.shade800),
                                const SizedBox(width: 8),
                                Text('Sin conexión - Modo offline',
                                    style: TextStyle(
                                        color: Colors.red.shade800,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(width: 8),
                                Icon(Icons.refresh,
                                    size: 16, color: Colors.red.shade800),
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

  void _initCatalogSync(BuildContext context) {
    try {
      final catalogSync =
          Provider.of<CatalogSyncService>(context, listen: false);
      debugPrint('📦 Iniciando sincronización de catálogos...');
      catalogSync.syncCatalogsIfNeeded();
    } catch (e) {
      debugPrint('⚠️ Error iniciando sync de catálogos: $e');
    }
  }
}
