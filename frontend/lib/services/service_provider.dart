// lib/services/service_provider.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../core/config/flavor_config.dart';
import '../data/datasources/auth_service.dart';
import '../data/database/app_database.dart';
import 'monitoreo_service.dart';
import 'intranet_service.dart';
import 'sincro_service.dart';
import 'offline_database_service.dart';
import 'sync_queue_service.dart';
import 'cache_service.dart';
import 'catalog_sync_service.dart';

class ServiceProvider extends StatelessWidget {
  final Widget child;
  final IntranetService intranetService;
  final ApiConfig apiConfig;
  final AppDatabase database;
  final OfflineDatabaseService offlineDbService;
  final AuthService authService; // ✅ NUEVO: Agregar parámetro

  const ServiceProvider({
    Key? key,
    required this.child,
    required this.intranetService,
    required this.apiConfig,
    required this.database,
    required this.offlineDbService,
    required this.authService, // ✅ NUEVO: Agregar parámetro requerido
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Configuración
        ChangeNotifierProvider.value(value: apiConfig),
        Provider<IntranetService>.value(value: intranetService),

        // CacheService (singleton para compatibilidad)
        Provider<CacheService>(
          create: (_) => CacheService(),
        ),

        // Base de datos SQLite
        Provider<AppDatabase>.value(value: database),
        ChangeNotifierProvider<OfflineDatabaseService>.value(
            value: offlineDbService),

        // CatalogSyncService - Sincronización de catálogos
        ChangeNotifierProvider<CatalogSyncService>(
          create: (context) => CatalogSyncService(
            offlineDbService: offlineDbService,
            intranetService: intranetService,
            apiConfig: apiConfig,
          ),
        ),

        // ✅ MODIFICADO: AuthService - Usar instancia existente en vez de crear nueva
        ChangeNotifierProvider<AuthService>.value(
          value: authService, // ✅ Usar la instancia pasada desde main.dart
        ),

        // SyncQueueService
        Provider<SyncQueueService>(
          create: (context) {
            final config = Provider.of<ApiConfig>(context, listen: false);
            final dio = Dio(BaseOptions(
              baseUrl: config.apiUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'Content-Type': 'application/json'},
            ));

            return SyncQueueService(
              database: database,
              dio: dio,
              baseUrl: config.apiUrl,
            );
          },
          dispose: (context, service) => service.dispose(),
        ),

        // MonitoreoService
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

        // SincronizacionService
        ProxyProvider3<MonitoreoService, IntranetService, SyncQueueService,
            SincronizacionService>(
          create: (context) => SincronizacionService(
            monitoreoService:
                Provider.of<MonitoreoService>(context, listen: false),
            intranetService: intranetService,
            syncQueueService:
                Provider.of<SyncQueueService>(context, listen: false),
          ),
          update: (context, monitoreoService, intranetService, syncQueueService,
              previous) {
            if (previous == null) {
              return SincronizacionService(
                monitoreoService: monitoreoService,
                intranetService: intranetService,
                syncQueueService: syncQueueService,
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
