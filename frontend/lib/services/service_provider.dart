import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/config/flavor_config.dart';
import '../data/datasources/auth_service.dart';
import 'monitoreo_service.dart';
import 'intranet_service.dart';
import 'cache_service.dart';
import 'sincro_service.dart';

/// Proveedor centralizado de servicios para la aplicación
/// Configura todas las dependencias y servicios necesarios
class ServiceProvider extends StatelessWidget {
  final Widget child;
  final IntranetService intranetService;
  final ApiConfig apiConfig;

  const ServiceProvider({
    Key? key,
    required this.child,
    required this.intranetService,
    required this.apiConfig,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Configuración de la API (siempre disponible)
        ChangeNotifierProvider.value(
          value: apiConfig,
        ),

        // Servicios de conectividad y caché
        Provider<IntranetService>.value(
          value: intranetService,
        ),
        Provider<CacheService>(
          create: (_) => CacheService(),
        ),

        // AuthService con la nueva dependencia de ApiConfig
        ChangeNotifierProvider(
          create: (context) => AuthService(
            Provider.of<ApiConfig>(context, listen: false),
          ),
        ),

        // MonitoreoService, que depende de AuthService y ApiConfig
        ChangeNotifierProxyProvider2<AuthService, ApiConfig, MonitoreoService>(
          create: (context) => MonitoreoService(
            Provider.of<AuthService>(context, listen: false),
            Provider.of<ApiConfig>(context, listen: false),
          ),
          update: (context, authService, apiConfig, previous) {
            if (previous == null) {
              return MonitoreoService(authService, apiConfig);
            }
            return previous;
          },
        ),

        // SincronizacionService que depende de servicios anteriores
        ProxyProvider3<MonitoreoService, IntranetService, CacheService,
            SincronizacionService>(
          create: (context) => SincronizacionService(
            monitoreoService:
                Provider.of<MonitoreoService>(context, listen: false),
            intranetService: intranetService,
            cacheService: Provider.of<CacheService>(context, listen: false),
          ),
          update: (context, monitoreoService, intranetService, cacheService,
              previous) {
            if (previous == null) {
              return SincronizacionService(
                monitoreoService: monitoreoService,
                intranetService: intranetService,
                cacheService: cacheService,
              );
            }
            return previous;
          },
          dispose: (context, service) => service.dispose(),
        ),
      ],
      child: child,
    );
  }
}
