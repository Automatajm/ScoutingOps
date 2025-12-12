// lib/data/database/app_database.dart
// ============================================================
// BASE DE DATOS LOCAL - VERSIÓN SIMPLIFICADA
// ============================================================
// COMPATIBLE CON CÓDIGO GENERADO EXISTENTE
// NO requiere ejecutar build_runner
// ============================================================

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';

part 'app_database.g.dart';

// ==========================================================================
// TABLA: outbox (Cola de operaciones pendientes)
// ==========================================================================
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get idempotencyKey => text().unique()();
  IntColumn get userId => integer()();
  TextColumn get operation => text()();
  TextColumn get payload => text()();
  IntColumn get tempId => integer().nullable()();
  IntColumn get serverId => integer().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  IntColumn get maxRetries => integer().withDefault(const Constant(5))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastAttempt => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get errorMessage => text().nullable()();
}

// ==========================================================================
// TABLA: monitoreos_local (Cache local de monitoreos)
// ==========================================================================
class MonitoreosLocal extends Table {
  IntColumn get pmmoSecuencia => integer()();
  TextColumn get pmltCodigo => text().nullable()();
  TextColumn get pmmoCasa => text().nullable()();
  TextColumn get pmmoCantero => text().nullable()();
  TextColumn get pmmoCanteros => text().nullable()();
  TextColumn get pmmoVariedad => text().nullable()();
  TextColumn get pmmoGrower => text().nullable()();
  TextColumn get pmniNombrecomun => text().nullable()();
  IntColumn get pmmoCantidad => integer().nullable()();
  IntColumn get pmmoCantBotada => integer().nullable()();
  TextColumn get pmmoComentarios => text().nullable()();
  DateTimeColumn get pmmoFecha => dateTime().nullable()();
  BoolColumn get pmmoAutomatico =>
      boolean().withDefault(const Constant(true))();
  IntColumn get pmmoEstatus => integer().withDefault(const Constant(1))();
  IntColumn get pmmoCreadopor => integer().nullable()();
  TextColumn get pmmoContenedor => text().nullable()();
  TextColumn get pmmoIdvariedad => text().nullable()();
  IntColumn get pmniId => integer().nullable()();
  IntColumn get pmmoMuestra1 => integer().nullable()();
  IntColumn get pmmoMuestra2 => integer().nullable()();
  IntColumn get pmmoMuestra3 => integer().nullable()();
  IntColumn get pmmoNivmuestraa1 => integer().nullable()();
  IntColumn get pmmoNivmuestraa2 => integer().nullable()();
  IntColumn get pmmoNivmuestraa3 => integer().nullable()();
  IntColumn get pmmoNivmuestram1 => integer().nullable()();
  IntColumn get pmmoNivmuestram2 => integer().nullable()();
  IntColumn get pmmoNivmuestram3 => integer().nullable()();
  IntColumn get lmsupniv1 => integer().nullable()();
  IntColumn get lmsupniv2 => integer().nullable()();
  IntColumn get lmsupniv3 => integer().nullable()();

  // Campos de sincronización que YA existen en .g.dart
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isLocal => boolean().withDefault(const Constant(false))();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {pmmoSecuencia};
}

// ==========================================================================
// TABLA: catalogos (Datos de referencia cacheados)
// ==========================================================================
class Catalogos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tipo => text()();
  TextColumn get clave => text().nullable()();
  TextColumn get data => text()();
  DateTimeColumn get updatedAt => dateTime()();
}

// ==========================================================================
// TABLA: sync_metadata (Control de sincronización)
// ==========================================================================
class SyncMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ==========================================================================
// DATABASE CLASS
// ==========================================================================
@DriftDatabase(tables: [Outbox, MonitoreosLocal, Catalogos, SyncMetadata])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ========================================================================
  // MIGRACIÓN DE ESQUEMA
  // ========================================================================
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Sin migraciones por ahora
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // ========================================================================
  // OUTBOX OPERATIONS
  // ========================================================================

  Future<int> addToOutbox({
    required String idempotencyKey,
    required int userId,
    required String operation,
    required String payload,
    int? tempId,
  }) {
    return into(outbox).insert(OutboxCompanion.insert(
      idempotencyKey: idempotencyKey,
      userId: userId,
      operation: operation,
      payload: payload,
      tempId: Value(tempId),
      createdAt: DateTime.now(),
      status: const Value('pending'),
    ));
  }

  Future<List<OutboxData>> getPendingOperations() {
    return (select(outbox)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<List<OutboxData>> getFailedOperations() {
    return (select(outbox)
          ..where((t) =>
              t.status.equals('failed') & t.retryCount.isSmallerThanValue(5))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<int> markOperationCompleted(int id, int? serverId) {
    return (update(outbox)..where((t) => t.id.equals(id))).write(
      OutboxCompanion(
        status: const Value('completed'),
        serverId: Value(serverId),
      ),
    );
  }

  Future<int> markOperationFailed(int id, String errorMessage) {
    return customUpdate(
      'UPDATE outbox SET status = ?, error_message = ?, last_attempt = ?, retry_count = retry_count + 1 WHERE id = ?',
      variables: [
        Variable.withString('failed'),
        Variable.withString(errorMessage),
        Variable.withDateTime(DateTime.now()),
        Variable.withInt(id),
      ],
      updates: {outbox},
    );
  }

  Future<int> markOperationSyncing(int id) {
    return (update(outbox)..where((t) => t.id.equals(id))).write(
      const OutboxCompanion(status: Value('syncing')),
    );
  }

  Future<int> removeCompletedOperation(int id) {
    return (delete(outbox)..where((t) => t.id.equals(id))).go();
  }

  Future<int> clearCompletedOperations() {
    return (delete(outbox)..where((t) => t.status.equals('completed'))).go();
  }

  Future<OutboxData?> findByIdempotencyKey(String key) {
    return (select(outbox)..where((t) => t.idempotencyKey.equals(key)))
        .getSingleOrNull();
  }

  Future<int> countPendingOperations() async {
    final result = await customSelect(
      'SELECT COUNT(*) as count FROM outbox WHERE status = ?',
      variables: [Variable.withString('pending')],
    ).getSingle();
    return result.read<int>('count');
  }

  // ========================================================================
  // MONITOREOS LOCAL OPERATIONS
  // ========================================================================

  Future<int> saveMonitoreoLocal(MonitoreosLocalCompanion monitoreo) {
    return into(monitoreosLocal).insertOnConflictUpdate(monitoreo);
  }

  Future<MonitoreosLocalData?> getMonitoreoById(int id) {
    return (select(monitoreosLocal)..where((t) => t.pmmoSecuencia.equals(id)))
        .getSingleOrNull();
  }

  Future<List<MonitoreosLocalData>> getAllMonitoreosLocales() {
    return (select(monitoreosLocal)
          ..orderBy([(t) => OrderingTerm.desc(t.pmmoFecha)]))
        .get();
  }

  Future<List<MonitoreosLocalData>> getMonitoreosByUser(int userId) {
    return (select(monitoreosLocal)
          ..where((t) => t.pmmoCreadopor.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.pmmoFecha)]))
        .get();
  }

  Future<List<MonitoreosLocalData>> getMonitoreosLocalOnly() {
    return (select(monitoreosLocal)..where((t) => t.isLocal.equals(true)))
        .get();
  }

  // ========== MÉTODOS DE SINCRONIZACIÓN SIMPLIFICADOS ==========

  /// Obtiene monitoreos pendientes de sincronización (usando isLocal)
  Future<List<MonitoreosLocalData>> getMonitoreosPendientesSync() {
    return (select(monitoreosLocal)
          ..where((t) =>
              t.isLocal.equals(true) | t.pmmoSecuencia.isSmallerThanValue(0))
          ..orderBy([(t) => OrderingTerm.asc(t.pmmoFecha)]))
        .get();
  }

  /// Obtiene monitoreos pendientes de sync para un usuario
  Future<List<MonitoreosLocalData>> getMonitoreosPendientesSyncByUser(
      int userId) {
    return (select(monitoreosLocal)
          ..where((t) =>
              t.pmmoCreadopor.equals(userId) &
              (t.isLocal.equals(true) | t.pmmoSecuencia.isSmallerThanValue(0)))
          ..orderBy([(t) => OrderingTerm.asc(t.pmmoFecha)]))
        .get();
  }

  /// Cuenta monitoreos pendientes de sincronización
  Future<int> countPendingSync() async {
    final result = await customSelect(
      'SELECT COUNT(*) as count FROM monitoreos_local WHERE is_local = 1 OR pmmo_secuencia < 0',
    ).getSingle();
    return result.read<int>('count');
  }

  /// Marca un monitoreo como sincronizado
  Future<int> markMonitoreoSynced(int id, int serverVersion,
      {int? newServerId}) async {
    if (newServerId != null && newServerId != id) {
      await updateTempIdToServerId(id, newServerId);
      id = newServerId;
    }

    return (update(monitoreosLocal)..where((t) => t.pmmoSecuencia.equals(id)))
        .write(MonitoreosLocalCompanion(
      isLocal: const Value(false),
      version: Value(serverVersion),
      syncedAt: Value(DateTime.now()),
    ));
  }

  /// Actualiza ID temporal a ID del servidor
  Future<void> updateTempIdToServerId(int tempId, int serverId) async {
    final existing = await getMonitoreoById(tempId);
    if (existing == null) return;

    await (delete(monitoreosLocal)
          ..where((t) => t.pmmoSecuencia.equals(tempId)))
        .go();

    await into(monitoreosLocal).insert(MonitoreosLocalCompanion(
      pmmoSecuencia: Value(serverId),
      pmltCodigo: Value(existing.pmltCodigo),
      pmmoCasa: Value(existing.pmmoCasa),
      pmmoCantero: Value(existing.pmmoCantero),
      pmmoCanteros: Value(existing.pmmoCanteros),
      pmmoVariedad: Value(existing.pmmoVariedad),
      pmmoGrower: Value(existing.pmmoGrower),
      pmniNombrecomun: Value(existing.pmniNombrecomun),
      pmmoCantidad: Value(existing.pmmoCantidad),
      pmmoCantBotada: Value(existing.pmmoCantBotada),
      pmmoComentarios: Value(existing.pmmoComentarios),
      pmmoFecha: Value(existing.pmmoFecha),
      pmmoAutomatico: Value(existing.pmmoAutomatico),
      pmmoEstatus: Value(existing.pmmoEstatus),
      pmmoCreadopor: Value(existing.pmmoCreadopor),
      pmmoContenedor: Value(existing.pmmoContenedor),
      pmmoIdvariedad: Value(existing.pmmoIdvariedad),
      pmniId: Value(existing.pmniId),
      pmmoMuestra1: Value(existing.pmmoMuestra1),
      pmmoMuestra2: Value(existing.pmmoMuestra2),
      pmmoMuestra3: Value(existing.pmmoMuestra3),
      pmmoNivmuestraa1: Value(existing.pmmoNivmuestraa1),
      pmmoNivmuestraa2: Value(existing.pmmoNivmuestraa2),
      pmmoNivmuestraa3: Value(existing.pmmoNivmuestraa3),
      pmmoNivmuestram1: Value(existing.pmmoNivmuestram1),
      pmmoNivmuestram2: Value(existing.pmmoNivmuestram2),
      pmmoNivmuestram3: Value(existing.pmmoNivmuestram3),
      lmsupniv1: Value(existing.lmsupniv1),
      lmsupniv2: Value(existing.lmsupniv2),
      lmsupniv3: Value(existing.lmsupniv3),
      version: Value(existing.version),
      isLocal: const Value(false),
      syncedAt: Value(DateTime.now()),
    ));
  }

  // ========== LIMPIEZA AUTOMÁTICA ==========

  /// Limpia registros antiguos que ya fueron sincronizados
  Future<int> cleanOldSyncedRecords() async {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    final deleted = await customUpdate(
      '''
      DELETE FROM monitoreos_local 
      WHERE is_local = 0 
        AND pmmo_secuencia > 0
        AND pmmo_fecha < ?
      ''',
      variables: [Variable.withDateTime(yesterday)],
      updates: {monitoreosLocal},
    );

    if (deleted > 0) {
      debugPrint(
          '🧹 Limpieza automática: $deleted registros antiguos eliminados');
    }

    return deleted;
  }

  /// Obtiene estadísticas de almacenamiento local
  Future<Map<String, int>> getStorageStats() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    final totalResult =
        await customSelect('SELECT COUNT(*) as count FROM monitoreos_local')
            .getSingle();

    final todayResult = await customSelect(
      'SELECT COUNT(*) as count FROM monitoreos_local WHERE date(pmmo_fecha) = date(?)',
      variables: [Variable.withDateTime(today)],
    ).getSingle();

    final yesterdayResult = await customSelect(
      'SELECT COUNT(*) as count FROM monitoreos_local WHERE date(pmmo_fecha) = date(?)',
      variables: [Variable.withDateTime(yesterday)],
    ).getSingle();

    final pendingResult = await customSelect(
            'SELECT COUNT(*) as count FROM monitoreos_local WHERE is_local = 1 OR pmmo_secuencia < 0')
        .getSingle();

    return {
      'total': totalResult.read<int>('count'),
      'today': todayResult.read<int>('count'),
      'yesterday': yesterdayResult.read<int>('count'),
      'pending_sync': pendingResult.read<int>('count'),
    };
  }

  /// Aplica cambios recibidos del servidor
  Future<void> applyServerChanges(List<Map<String, dynamic>> serverData) async {
    for (final data in serverData) {
      final serverId = data['pmmo_secuencia'] as int;
      final serverVersion = data['version'] as int? ?? 1;

      final local = await getMonitoreoById(serverId);

      if (local == null) {
        await _insertFromServerData(data, serverVersion);
      } else if (!local.isLocal) {
        // Solo actualizar si no tiene cambios locales pendientes
        if (serverVersion > local.version) {
          await _updateFromServerData(serverId, data, serverVersion);
        }
      } else {
        // Conflicto: server wins
        debugPrint(
            '⚠️ Conflicto detectado para monitoreo $serverId - server wins');
        await _updateFromServerData(serverId, data, serverVersion);
      }
    }
  }

  Future<void> _insertFromServerData(
      Map<String, dynamic> data, int serverVersion) async {
    await into(monitoreosLocal).insert(MonitoreosLocalCompanion(
      pmmoSecuencia: Value(data['pmmo_secuencia'] as int),
      pmltCodigo: Value(data['pmlt_codigo'] as String?),
      pmmoCasa: Value(data['pmmo_casa'] as String?),
      pmmoCantero: Value(data['pmmo_cantero'] as String?),
      pmmoCanteros: Value(data['pmmo_canteros'] as String?),
      pmmoVariedad: Value(data['pmmo_variedad'] as String?),
      pmmoGrower: Value(data['pmmo_grower'] as String?),
      pmniNombrecomun: Value(data['pmni_nombrecomun'] as String?),
      pmmoCantidad: Value(data['pmmo_cantidad'] as int?),
      pmmoCantBotada: Value(data['pmmo_cant_botada'] as int?),
      pmmoComentarios: Value(data['pmmo_comentarios'] as String?),
      pmmoFecha: Value(_parseDateTime(data['pmmo_fecha'])),
      pmmoAutomatico: Value(data['pmmo_automatico'] as bool? ?? true),
      pmmoEstatus: Value(data['pmmo_estatus'] as int? ?? 1),
      pmmoCreadopor: Value(data['pmmo_creadopor'] as int?),
      pmmoContenedor: Value(data['pmmo_contenedor'] as String?),
      pmmoIdvariedad: Value(data['pmmo_idvariedad'] as String?),
      pmniId: Value(data['pmni_id'] as int?),
      pmmoMuestra1: Value(data['pmmo_muestra1'] as int?),
      pmmoMuestra2: Value(data['pmmo_muestra2'] as int?),
      pmmoMuestra3: Value(data['pmmo_muestra3'] as int?),
      pmmoNivmuestraa1: Value(data['pmmo_nivmuestraa1'] as int?),
      pmmoNivmuestraa2: Value(data['pmmo_nivmuestraa2'] as int?),
      pmmoNivmuestraa3: Value(data['pmmo_nivmuestraa3'] as int?),
      pmmoNivmuestram1: Value(data['pmmo_nivmuestram1'] as int?),
      pmmoNivmuestram2: Value(data['pmmo_nivmuestram2'] as int?),
      pmmoNivmuestram3: Value(data['pmmo_nivmuestram3'] as int?),
      lmsupniv1: Value(data['lmsupniv1'] as int?),
      lmsupniv2: Value(data['lmsupniv2'] as int?),
      lmsupniv3: Value(data['lmsupniv3'] as int?),
      version: Value(serverVersion),
      isLocal: const Value(false),
      syncedAt: Value(DateTime.now()),
    ));
  }

  Future<void> _updateFromServerData(
      int id, Map<String, dynamic> data, int serverVersion) async {
    await (update(monitoreosLocal)..where((t) => t.pmmoSecuencia.equals(id)))
        .write(MonitoreosLocalCompanion(
      pmltCodigo: Value(data['pmlt_codigo'] as String?),
      pmmoCasa: Value(data['pmmo_casa'] as String?),
      pmmoCantero: Value(data['pmmo_cantero'] as String?),
      pmmoCanteros: Value(data['pmmo_canteros'] as String?),
      pmmoVariedad: Value(data['pmmo_variedad'] as String?),
      pmmoGrower: Value(data['pmmo_grower'] as String?),
      pmniNombrecomun: Value(data['pmni_nombrecomun'] as String?),
      pmmoCantidad: Value(data['pmmo_cantidad'] as int?),
      pmmoCantBotada: Value(data['pmmo_cant_botada'] as int?),
      pmmoComentarios: Value(data['pmmo_comentarios'] as String?),
      pmmoFecha: Value(_parseDateTime(data['pmmo_fecha'])),
      pmmoAutomatico: Value(data['pmmo_automatico'] as bool? ?? true),
      pmmoEstatus: Value(data['pmmo_estatus'] as int? ?? 1),
      pmmoContenedor: Value(data['pmmo_contenedor'] as String?),
      pmmoIdvariedad: Value(data['pmmo_idvariedad'] as String?),
      pmniId: Value(data['pmni_id'] as int?),
      pmmoMuestra1: Value(data['pmmo_muestra1'] as int?),
      pmmoMuestra2: Value(data['pmmo_muestra2'] as int?),
      pmmoMuestra3: Value(data['pmmo_muestra3'] as int?),
      pmmoNivmuestraa1: Value(data['pmmo_nivmuestraa1'] as int?),
      pmmoNivmuestraa2: Value(data['pmmo_nivmuestraa2'] as int?),
      pmmoNivmuestraa3: Value(data['pmmo_nivmuestraa3'] as int?),
      pmmoNivmuestram1: Value(data['pmmo_nivmuestram1'] as int?),
      pmmoNivmuestram2: Value(data['pmmo_nivmuestram2'] as int?),
      pmmoNivmuestram3: Value(data['pmmo_nivmuestram3'] as int?),
      lmsupniv1: Value(data['lmsupniv1'] as int?),
      lmsupniv2: Value(data['lmsupniv2'] as int?),
      lmsupniv3: Value(data['lmsupniv3'] as int?),
      version: Value(serverVersion),
      isLocal: const Value(false),
      syncedAt: Value(DateTime.now()),
    ));
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Future<int> deleteMonitoreoLocal(int id) {
    return (delete(monitoreosLocal)..where((t) => t.pmmoSecuencia.equals(id)))
        .go();
  }

  Future<int> clearAllMonitoreosLocales() {
    return delete(monitoreosLocal).go();
  }

  // ========================================================================
  // CATALOGOS OPERATIONS
  // ========================================================================

  Future<int> saveCatalogo(String tipo, String data, {String? clave}) async {
    await deleteCatalogo(tipo, clave: clave);
    return into(catalogos).insert(CatalogosCompanion(
      tipo: Value(tipo),
      clave: Value(clave),
      data: Value(data),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<Map<String, dynamic>?> getCatalogo(String tipo,
      {String? clave}) async {
    final String sql;
    final List<Variable> variables;

    if (clave != null) {
      sql =
          'SELECT * FROM catalogos WHERE tipo = ? AND clave = ? ORDER BY updated_at DESC LIMIT 1';
      variables = [Variable.withString(tipo), Variable.withString(clave)];
    } else {
      sql =
          'SELECT * FROM catalogos WHERE tipo = ? AND clave IS NULL ORDER BY updated_at DESC LIMIT 1';
      variables = [Variable.withString(tipo)];
    }

    final results = await customSelect(sql, variables: variables).get();
    if (results.isEmpty) return null;

    final row = results.first;
    return {
      'id': row.read<int>('id'),
      'tipo': row.read<String>('tipo'),
      'clave': row.readNullable<String>('clave'),
      'data': row.read<String>('data'),
      'updatedAt': row.read<DateTime>('updated_at'),
    };
  }

  Future<int> deleteCatalogo(String tipo, {String? clave}) {
    var query = delete(catalogos)..where((t) => t.tipo.equals(tipo));
    if (clave != null) {
      query = query..where((t) => t.clave.equals(clave));
    } else {
      query = query..where((t) => t.clave.isNull());
    }
    return query.go();
  }

  Future<int> clearAllCatalogos() {
    return delete(catalogos).go();
  }

  // ========================================================================
  // SYNC METADATA OPERATIONS
  // ========================================================================

  Future<int> saveSyncMetadata(String key, String value) {
    return into(syncMetadata).insertOnConflictUpdate(SyncMetadataCompanion(
      key: Value(key),
      value: Value(value),
    ));
  }

  Future<String?> getSyncMetadata(String key) async {
    final result = await (select(syncMetadata)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return result?.value;
  }

  Future<DateTime?> getLastSyncTime() async {
    final value = await getSyncMetadata('last_sync_monitoreos');
    if (value != null && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  Future<void> saveLastSyncTime([DateTime? time]) async {
    final timestamp = (time ?? DateTime.now()).toIso8601String();
    await saveSyncMetadata('last_sync_monitoreos', timestamp);
  }

  // ========================================================================
  // UTILITY METHODS
  // ========================================================================

  Future<void> clearAllData() async {
    await clearCompletedOperations();
    await clearAllMonitoreosLocales();
    await clearAllCatalogos();
    await delete(syncMetadata).go();
  }

  Future<Map<String, dynamic>> getDatabaseStats() async {
    final pendingOps = await countPendingOperations();
    final storageStats = await getStorageStats();
    final catalogosResult = await customSelect(
      'SELECT COUNT(*) as count FROM catalogos',
    ).getSingle();

    return {
      'pending_operations': pendingOps,
      'monitoreos': storageStats,
      'catalogos': catalogosResult.read<int>('count'),
    };
  }

  /// Genera un ID temporal único (negativo) para registros offline
  int generateTempId() {
    return -DateTime.now().millisecondsSinceEpoch;
  }
}

// ==========================================================================
// DATABASE CONNECTION (Web con IndexedDB/OPFS)
// ==========================================================================
DatabaseConnection _openConnection() {
  return DatabaseConnection.delayed(Future(() async {
    final result = await WasmDatabase.open(
      databaseName: 'pestcontrol_db',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );

    if (result.missingFeatures.isNotEmpty) {
      debugPrint(
          'Using ${result.chosenImplementation} due to missing browser features: ${result.missingFeatures}');
    }

    return result.resolvedExecutor;
  }));
}
