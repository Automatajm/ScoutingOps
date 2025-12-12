// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _idempotencyKeyMeta =
      const VerificationMeta('idempotencyKey');
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
      'idempotency_key', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
      'user_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _operationMeta =
      const VerificationMeta('operation');
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
      'operation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tempIdMeta = const VerificationMeta('tempId');
  @override
  late final GeneratedColumn<int> tempId = GeneratedColumn<int>(
      'temp_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _serverIdMeta =
      const VerificationMeta('serverId');
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
      'server_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _retryCountMeta =
      const VerificationMeta('retryCount');
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
      'retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _maxRetriesMeta =
      const VerificationMeta('maxRetries');
  @override
  late final GeneratedColumn<int> maxRetries = GeneratedColumn<int>(
      'max_retries', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(5));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _lastAttemptMeta =
      const VerificationMeta('lastAttempt');
  @override
  late final GeneratedColumn<DateTime> lastAttempt = GeneratedColumn<DateTime>(
      'last_attempt', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _errorMessageMeta =
      const VerificationMeta('errorMessage');
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
      'error_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        idempotencyKey,
        userId,
        operation,
        payload,
        tempId,
        serverId,
        retryCount,
        maxRetries,
        createdAt,
        lastAttempt,
        status,
        errorMessage
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
          _idempotencyKeyMeta,
          idempotencyKey.isAcceptableOrUnknown(
              data['idempotency_key']!, _idempotencyKeyMeta));
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(_operationMeta,
          operation.isAcceptableOrUnknown(data['operation']!, _operationMeta));
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('temp_id')) {
      context.handle(_tempIdMeta,
          tempId.isAcceptableOrUnknown(data['temp_id']!, _tempIdMeta));
    }
    if (data.containsKey('server_id')) {
      context.handle(_serverIdMeta,
          serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta));
    }
    if (data.containsKey('retry_count')) {
      context.handle(
          _retryCountMeta,
          retryCount.isAcceptableOrUnknown(
              data['retry_count']!, _retryCountMeta));
    }
    if (data.containsKey('max_retries')) {
      context.handle(
          _maxRetriesMeta,
          maxRetries.isAcceptableOrUnknown(
              data['max_retries']!, _maxRetriesMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_attempt')) {
      context.handle(
          _lastAttemptMeta,
          lastAttempt.isAcceptableOrUnknown(
              data['last_attempt']!, _lastAttemptMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('error_message')) {
      context.handle(
          _errorMessageMeta,
          errorMessage.isAcceptableOrUnknown(
              data['error_message']!, _errorMessageMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      idempotencyKey: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}idempotency_key'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}user_id'])!,
      operation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      tempId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}temp_id']),
      serverId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}server_id']),
      retryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}retry_count'])!,
      maxRetries: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}max_retries'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      lastAttempt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_attempt']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      errorMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error_message']),
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  final int id;
  final String idempotencyKey;
  final int userId;
  final String operation;
  final String payload;
  final int? tempId;
  final int? serverId;
  final int retryCount;
  final int maxRetries;
  final DateTime createdAt;
  final DateTime? lastAttempt;
  final String status;
  final String? errorMessage;
  const OutboxData(
      {required this.id,
      required this.idempotencyKey,
      required this.userId,
      required this.operation,
      required this.payload,
      this.tempId,
      this.serverId,
      required this.retryCount,
      required this.maxRetries,
      required this.createdAt,
      this.lastAttempt,
      required this.status,
      this.errorMessage});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['user_id'] = Variable<int>(userId);
    map['operation'] = Variable<String>(operation);
    map['payload'] = Variable<String>(payload);
    if (!nullToAbsent || tempId != null) {
      map['temp_id'] = Variable<int>(tempId);
    }
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['retry_count'] = Variable<int>(retryCount);
    map['max_retries'] = Variable<int>(maxRetries);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastAttempt != null) {
      map['last_attempt'] = Variable<DateTime>(lastAttempt);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      id: Value(id),
      idempotencyKey: Value(idempotencyKey),
      userId: Value(userId),
      operation: Value(operation),
      payload: Value(payload),
      tempId:
          tempId == null && nullToAbsent ? const Value.absent() : Value(tempId),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      retryCount: Value(retryCount),
      maxRetries: Value(maxRetries),
      createdAt: Value(createdAt),
      lastAttempt: lastAttempt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttempt),
      status: Value(status),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
    );
  }

  factory OutboxData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      id: serializer.fromJson<int>(json['id']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      userId: serializer.fromJson<int>(json['userId']),
      operation: serializer.fromJson<String>(json['operation']),
      payload: serializer.fromJson<String>(json['payload']),
      tempId: serializer.fromJson<int?>(json['tempId']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      maxRetries: serializer.fromJson<int>(json['maxRetries']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastAttempt: serializer.fromJson<DateTime?>(json['lastAttempt']),
      status: serializer.fromJson<String>(json['status']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'userId': serializer.toJson<int>(userId),
      'operation': serializer.toJson<String>(operation),
      'payload': serializer.toJson<String>(payload),
      'tempId': serializer.toJson<int?>(tempId),
      'serverId': serializer.toJson<int?>(serverId),
      'retryCount': serializer.toJson<int>(retryCount),
      'maxRetries': serializer.toJson<int>(maxRetries),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastAttempt': serializer.toJson<DateTime?>(lastAttempt),
      'status': serializer.toJson<String>(status),
      'errorMessage': serializer.toJson<String?>(errorMessage),
    };
  }

  OutboxData copyWith(
          {int? id,
          String? idempotencyKey,
          int? userId,
          String? operation,
          String? payload,
          Value<int?> tempId = const Value.absent(),
          Value<int?> serverId = const Value.absent(),
          int? retryCount,
          int? maxRetries,
          DateTime? createdAt,
          Value<DateTime?> lastAttempt = const Value.absent(),
          String? status,
          Value<String?> errorMessage = const Value.absent()}) =>
      OutboxData(
        id: id ?? this.id,
        idempotencyKey: idempotencyKey ?? this.idempotencyKey,
        userId: userId ?? this.userId,
        operation: operation ?? this.operation,
        payload: payload ?? this.payload,
        tempId: tempId.present ? tempId.value : this.tempId,
        serverId: serverId.present ? serverId.value : this.serverId,
        retryCount: retryCount ?? this.retryCount,
        maxRetries: maxRetries ?? this.maxRetries,
        createdAt: createdAt ?? this.createdAt,
        lastAttempt: lastAttempt.present ? lastAttempt.value : this.lastAttempt,
        status: status ?? this.status,
        errorMessage:
            errorMessage.present ? errorMessage.value : this.errorMessage,
      );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      id: data.id.present ? data.id.value : this.id,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      userId: data.userId.present ? data.userId.value : this.userId,
      operation: data.operation.present ? data.operation.value : this.operation,
      payload: data.payload.present ? data.payload.value : this.payload,
      tempId: data.tempId.present ? data.tempId.value : this.tempId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      retryCount:
          data.retryCount.present ? data.retryCount.value : this.retryCount,
      maxRetries:
          data.maxRetries.present ? data.maxRetries.value : this.maxRetries,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastAttempt:
          data.lastAttempt.present ? data.lastAttempt.value : this.lastAttempt,
      status: data.status.present ? data.status.value : this.status,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('id: $id, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('userId: $userId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('tempId: $tempId, ')
          ..write('serverId: $serverId, ')
          ..write('retryCount: $retryCount, ')
          ..write('maxRetries: $maxRetries, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAttempt: $lastAttempt, ')
          ..write('status: $status, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      idempotencyKey,
      userId,
      operation,
      payload,
      tempId,
      serverId,
      retryCount,
      maxRetries,
      createdAt,
      lastAttempt,
      status,
      errorMessage);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.id == this.id &&
          other.idempotencyKey == this.idempotencyKey &&
          other.userId == this.userId &&
          other.operation == this.operation &&
          other.payload == this.payload &&
          other.tempId == this.tempId &&
          other.serverId == this.serverId &&
          other.retryCount == this.retryCount &&
          other.maxRetries == this.maxRetries &&
          other.createdAt == this.createdAt &&
          other.lastAttempt == this.lastAttempt &&
          other.status == this.status &&
          other.errorMessage == this.errorMessage);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<int> id;
  final Value<String> idempotencyKey;
  final Value<int> userId;
  final Value<String> operation;
  final Value<String> payload;
  final Value<int?> tempId;
  final Value<int?> serverId;
  final Value<int> retryCount;
  final Value<int> maxRetries;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastAttempt;
  final Value<String> status;
  final Value<String?> errorMessage;
  const OutboxCompanion({
    this.id = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.userId = const Value.absent(),
    this.operation = const Value.absent(),
    this.payload = const Value.absent(),
    this.tempId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.maxRetries = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastAttempt = const Value.absent(),
    this.status = const Value.absent(),
    this.errorMessage = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.id = const Value.absent(),
    required String idempotencyKey,
    required int userId,
    required String operation,
    required String payload,
    this.tempId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.maxRetries = const Value.absent(),
    required DateTime createdAt,
    this.lastAttempt = const Value.absent(),
    this.status = const Value.absent(),
    this.errorMessage = const Value.absent(),
  })  : idempotencyKey = Value(idempotencyKey),
        userId = Value(userId),
        operation = Value(operation),
        payload = Value(payload),
        createdAt = Value(createdAt);
  static Insertable<OutboxData> custom({
    Expression<int>? id,
    Expression<String>? idempotencyKey,
    Expression<int>? userId,
    Expression<String>? operation,
    Expression<String>? payload,
    Expression<int>? tempId,
    Expression<int>? serverId,
    Expression<int>? retryCount,
    Expression<int>? maxRetries,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastAttempt,
    Expression<String>? status,
    Expression<String>? errorMessage,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (userId != null) 'user_id': userId,
      if (operation != null) 'operation': operation,
      if (payload != null) 'payload': payload,
      if (tempId != null) 'temp_id': tempId,
      if (serverId != null) 'server_id': serverId,
      if (retryCount != null) 'retry_count': retryCount,
      if (maxRetries != null) 'max_retries': maxRetries,
      if (createdAt != null) 'created_at': createdAt,
      if (lastAttempt != null) 'last_attempt': lastAttempt,
      if (status != null) 'status': status,
      if (errorMessage != null) 'error_message': errorMessage,
    });
  }

  OutboxCompanion copyWith(
      {Value<int>? id,
      Value<String>? idempotencyKey,
      Value<int>? userId,
      Value<String>? operation,
      Value<String>? payload,
      Value<int?>? tempId,
      Value<int?>? serverId,
      Value<int>? retryCount,
      Value<int>? maxRetries,
      Value<DateTime>? createdAt,
      Value<DateTime?>? lastAttempt,
      Value<String>? status,
      Value<String?>? errorMessage}) {
    return OutboxCompanion(
      id: id ?? this.id,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      userId: userId ?? this.userId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      tempId: tempId ?? this.tempId,
      serverId: serverId ?? this.serverId,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      createdAt: createdAt ?? this.createdAt,
      lastAttempt: lastAttempt ?? this.lastAttempt,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (tempId.present) {
      map['temp_id'] = Variable<int>(tempId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (maxRetries.present) {
      map['max_retries'] = Variable<int>(maxRetries.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastAttempt.present) {
      map['last_attempt'] = Variable<DateTime>(lastAttempt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('id: $id, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('userId: $userId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('tempId: $tempId, ')
          ..write('serverId: $serverId, ')
          ..write('retryCount: $retryCount, ')
          ..write('maxRetries: $maxRetries, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAttempt: $lastAttempt, ')
          ..write('status: $status, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }
}

class $MonitoreosLocalTable extends MonitoreosLocal
    with TableInfo<$MonitoreosLocalTable, MonitoreosLocalData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MonitoreosLocalTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pmmoSecuenciaMeta =
      const VerificationMeta('pmmoSecuencia');
  @override
  late final GeneratedColumn<int> pmmoSecuencia = GeneratedColumn<int>(
      'pmmo_secuencia', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _pmltCodigoMeta =
      const VerificationMeta('pmltCodigo');
  @override
  late final GeneratedColumn<String> pmltCodigo = GeneratedColumn<String>(
      'pmlt_codigo', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _pmmoCasaMeta =
      const VerificationMeta('pmmoCasa');
  @override
  late final GeneratedColumn<String> pmmoCasa = GeneratedColumn<String>(
      'pmmo_casa', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _pmmoCanteroMeta =
      const VerificationMeta('pmmoCantero');
  @override
  late final GeneratedColumn<String> pmmoCantero = GeneratedColumn<String>(
      'pmmo_cantero', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _pmmoCanterosMeta =
      const VerificationMeta('pmmoCanteros');
  @override
  late final GeneratedColumn<String> pmmoCanteros = GeneratedColumn<String>(
      'pmmo_canteros', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _pmmoVariedadMeta =
      const VerificationMeta('pmmoVariedad');
  @override
  late final GeneratedColumn<String> pmmoVariedad = GeneratedColumn<String>(
      'pmmo_variedad', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _pmmoGrowerMeta =
      const VerificationMeta('pmmoGrower');
  @override
  late final GeneratedColumn<String> pmmoGrower = GeneratedColumn<String>(
      'pmmo_grower', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _pmniNombrecomunMeta =
      const VerificationMeta('pmniNombrecomun');
  @override
  late final GeneratedColumn<String> pmniNombrecomun = GeneratedColumn<String>(
      'pmni_nombrecomun', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _pmmoCantidadMeta =
      const VerificationMeta('pmmoCantidad');
  @override
  late final GeneratedColumn<int> pmmoCantidad = GeneratedColumn<int>(
      'pmmo_cantidad', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _pmmoCantBotadaMeta =
      const VerificationMeta('pmmoCantBotada');
  @override
  late final GeneratedColumn<int> pmmoCantBotada = GeneratedColumn<int>(
      'pmmo_cant_botada', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _pmmoComentariosMeta =
      const VerificationMeta('pmmoComentarios');
  @override
  late final GeneratedColumn<String> pmmoComentarios = GeneratedColumn<String>(
      'pmmo_comentarios', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _pmmoFechaMeta =
      const VerificationMeta('pmmoFecha');
  @override
  late final GeneratedColumn<DateTime> pmmoFecha = GeneratedColumn<DateTime>(
      'pmmo_fecha', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _pmmoAutomaticoMeta =
      const VerificationMeta('pmmoAutomatico');
  @override
  late final GeneratedColumn<bool> pmmoAutomatico = GeneratedColumn<bool>(
      'pmmo_automatico', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("pmmo_automatico" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _pmmoEstatusMeta =
      const VerificationMeta('pmmoEstatus');
  @override
  late final GeneratedColumn<int> pmmoEstatus = GeneratedColumn<int>(
      'pmmo_estatus', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _pmmoCreadoporMeta =
      const VerificationMeta('pmmoCreadopor');
  @override
  late final GeneratedColumn<int> pmmoCreadopor = GeneratedColumn<int>(
      'pmmo_creadopor', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _pmmoContenedorMeta =
      const VerificationMeta('pmmoContenedor');
  @override
  late final GeneratedColumn<String> pmmoContenedor = GeneratedColumn<String>(
      'pmmo_contenedor', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _pmmoIdvariedadMeta =
      const VerificationMeta('pmmoIdvariedad');
  @override
  late final GeneratedColumn<String> pmmoIdvariedad = GeneratedColumn<String>(
      'pmmo_idvariedad', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _pmniIdMeta = const VerificationMeta('pmniId');
  @override
  late final GeneratedColumn<int> pmniId = GeneratedColumn<int>(
      'pmni_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _pmmoMuestra1Meta =
      const VerificationMeta('pmmoMuestra1');
  @override
  late final GeneratedColumn<int> pmmoMuestra1 = GeneratedColumn<int>(
      'pmmo_muestra1', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _pmmoMuestra2Meta =
      const VerificationMeta('pmmoMuestra2');
  @override
  late final GeneratedColumn<int> pmmoMuestra2 = GeneratedColumn<int>(
      'pmmo_muestra2', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _pmmoMuestra3Meta =
      const VerificationMeta('pmmoMuestra3');
  @override
  late final GeneratedColumn<int> pmmoMuestra3 = GeneratedColumn<int>(
      'pmmo_muestra3', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _pmmoNivmuestraa1Meta =
      const VerificationMeta('pmmoNivmuestraa1');
  @override
  late final GeneratedColumn<int> pmmoNivmuestraa1 = GeneratedColumn<int>(
      'pmmo_nivmuestraa1', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _pmmoNivmuestraa2Meta =
      const VerificationMeta('pmmoNivmuestraa2');
  @override
  late final GeneratedColumn<int> pmmoNivmuestraa2 = GeneratedColumn<int>(
      'pmmo_nivmuestraa2', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _pmmoNivmuestraa3Meta =
      const VerificationMeta('pmmoNivmuestraa3');
  @override
  late final GeneratedColumn<int> pmmoNivmuestraa3 = GeneratedColumn<int>(
      'pmmo_nivmuestraa3', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _pmmoNivmuestram1Meta =
      const VerificationMeta('pmmoNivmuestram1');
  @override
  late final GeneratedColumn<int> pmmoNivmuestram1 = GeneratedColumn<int>(
      'pmmo_nivmuestram1', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _pmmoNivmuestram2Meta =
      const VerificationMeta('pmmoNivmuestram2');
  @override
  late final GeneratedColumn<int> pmmoNivmuestram2 = GeneratedColumn<int>(
      'pmmo_nivmuestram2', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _pmmoNivmuestram3Meta =
      const VerificationMeta('pmmoNivmuestram3');
  @override
  late final GeneratedColumn<int> pmmoNivmuestram3 = GeneratedColumn<int>(
      'pmmo_nivmuestram3', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _lmsupniv1Meta =
      const VerificationMeta('lmsupniv1');
  @override
  late final GeneratedColumn<int> lmsupniv1 = GeneratedColumn<int>(
      'lmsupniv1', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _lmsupniv2Meta =
      const VerificationMeta('lmsupniv2');
  @override
  late final GeneratedColumn<int> lmsupniv2 = GeneratedColumn<int>(
      'lmsupniv2', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _lmsupniv3Meta =
      const VerificationMeta('lmsupniv3');
  @override
  late final GeneratedColumn<int> lmsupniv3 = GeneratedColumn<int>(
      'lmsupniv3', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _isLocalMeta =
      const VerificationMeta('isLocal');
  @override
  late final GeneratedColumn<bool> isLocal = GeneratedColumn<bool>(
      'is_local', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_local" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  @override
  List<GeneratedColumn> get $columns => [
        pmmoSecuencia,
        pmltCodigo,
        pmmoCasa,
        pmmoCantero,
        pmmoCanteros,
        pmmoVariedad,
        pmmoGrower,
        pmniNombrecomun,
        pmmoCantidad,
        pmmoCantBotada,
        pmmoComentarios,
        pmmoFecha,
        pmmoAutomatico,
        pmmoEstatus,
        pmmoCreadopor,
        pmmoContenedor,
        pmmoIdvariedad,
        pmniId,
        pmmoMuestra1,
        pmmoMuestra2,
        pmmoMuestra3,
        pmmoNivmuestraa1,
        pmmoNivmuestraa2,
        pmmoNivmuestraa3,
        pmmoNivmuestram1,
        pmmoNivmuestram2,
        pmmoNivmuestram3,
        lmsupniv1,
        lmsupniv2,
        lmsupniv3,
        isLocal,
        syncedAt,
        version
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'monitoreos_local';
  @override
  VerificationContext validateIntegrity(
      Insertable<MonitoreosLocalData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('pmmo_secuencia')) {
      context.handle(
          _pmmoSecuenciaMeta,
          pmmoSecuencia.isAcceptableOrUnknown(
              data['pmmo_secuencia']!, _pmmoSecuenciaMeta));
    }
    if (data.containsKey('pmlt_codigo')) {
      context.handle(
          _pmltCodigoMeta,
          pmltCodigo.isAcceptableOrUnknown(
              data['pmlt_codigo']!, _pmltCodigoMeta));
    }
    if (data.containsKey('pmmo_casa')) {
      context.handle(_pmmoCasaMeta,
          pmmoCasa.isAcceptableOrUnknown(data['pmmo_casa']!, _pmmoCasaMeta));
    }
    if (data.containsKey('pmmo_cantero')) {
      context.handle(
          _pmmoCanteroMeta,
          pmmoCantero.isAcceptableOrUnknown(
              data['pmmo_cantero']!, _pmmoCanteroMeta));
    }
    if (data.containsKey('pmmo_canteros')) {
      context.handle(
          _pmmoCanterosMeta,
          pmmoCanteros.isAcceptableOrUnknown(
              data['pmmo_canteros']!, _pmmoCanterosMeta));
    }
    if (data.containsKey('pmmo_variedad')) {
      context.handle(
          _pmmoVariedadMeta,
          pmmoVariedad.isAcceptableOrUnknown(
              data['pmmo_variedad']!, _pmmoVariedadMeta));
    }
    if (data.containsKey('pmmo_grower')) {
      context.handle(
          _pmmoGrowerMeta,
          pmmoGrower.isAcceptableOrUnknown(
              data['pmmo_grower']!, _pmmoGrowerMeta));
    }
    if (data.containsKey('pmni_nombrecomun')) {
      context.handle(
          _pmniNombrecomunMeta,
          pmniNombrecomun.isAcceptableOrUnknown(
              data['pmni_nombrecomun']!, _pmniNombrecomunMeta));
    }
    if (data.containsKey('pmmo_cantidad')) {
      context.handle(
          _pmmoCantidadMeta,
          pmmoCantidad.isAcceptableOrUnknown(
              data['pmmo_cantidad']!, _pmmoCantidadMeta));
    }
    if (data.containsKey('pmmo_cant_botada')) {
      context.handle(
          _pmmoCantBotadaMeta,
          pmmoCantBotada.isAcceptableOrUnknown(
              data['pmmo_cant_botada']!, _pmmoCantBotadaMeta));
    }
    if (data.containsKey('pmmo_comentarios')) {
      context.handle(
          _pmmoComentariosMeta,
          pmmoComentarios.isAcceptableOrUnknown(
              data['pmmo_comentarios']!, _pmmoComentariosMeta));
    }
    if (data.containsKey('pmmo_fecha')) {
      context.handle(_pmmoFechaMeta,
          pmmoFecha.isAcceptableOrUnknown(data['pmmo_fecha']!, _pmmoFechaMeta));
    }
    if (data.containsKey('pmmo_automatico')) {
      context.handle(
          _pmmoAutomaticoMeta,
          pmmoAutomatico.isAcceptableOrUnknown(
              data['pmmo_automatico']!, _pmmoAutomaticoMeta));
    }
    if (data.containsKey('pmmo_estatus')) {
      context.handle(
          _pmmoEstatusMeta,
          pmmoEstatus.isAcceptableOrUnknown(
              data['pmmo_estatus']!, _pmmoEstatusMeta));
    }
    if (data.containsKey('pmmo_creadopor')) {
      context.handle(
          _pmmoCreadoporMeta,
          pmmoCreadopor.isAcceptableOrUnknown(
              data['pmmo_creadopor']!, _pmmoCreadoporMeta));
    }
    if (data.containsKey('pmmo_contenedor')) {
      context.handle(
          _pmmoContenedorMeta,
          pmmoContenedor.isAcceptableOrUnknown(
              data['pmmo_contenedor']!, _pmmoContenedorMeta));
    }
    if (data.containsKey('pmmo_idvariedad')) {
      context.handle(
          _pmmoIdvariedadMeta,
          pmmoIdvariedad.isAcceptableOrUnknown(
              data['pmmo_idvariedad']!, _pmmoIdvariedadMeta));
    }
    if (data.containsKey('pmni_id')) {
      context.handle(_pmniIdMeta,
          pmniId.isAcceptableOrUnknown(data['pmni_id']!, _pmniIdMeta));
    }
    if (data.containsKey('pmmo_muestra1')) {
      context.handle(
          _pmmoMuestra1Meta,
          pmmoMuestra1.isAcceptableOrUnknown(
              data['pmmo_muestra1']!, _pmmoMuestra1Meta));
    }
    if (data.containsKey('pmmo_muestra2')) {
      context.handle(
          _pmmoMuestra2Meta,
          pmmoMuestra2.isAcceptableOrUnknown(
              data['pmmo_muestra2']!, _pmmoMuestra2Meta));
    }
    if (data.containsKey('pmmo_muestra3')) {
      context.handle(
          _pmmoMuestra3Meta,
          pmmoMuestra3.isAcceptableOrUnknown(
              data['pmmo_muestra3']!, _pmmoMuestra3Meta));
    }
    if (data.containsKey('pmmo_nivmuestraa1')) {
      context.handle(
          _pmmoNivmuestraa1Meta,
          pmmoNivmuestraa1.isAcceptableOrUnknown(
              data['pmmo_nivmuestraa1']!, _pmmoNivmuestraa1Meta));
    }
    if (data.containsKey('pmmo_nivmuestraa2')) {
      context.handle(
          _pmmoNivmuestraa2Meta,
          pmmoNivmuestraa2.isAcceptableOrUnknown(
              data['pmmo_nivmuestraa2']!, _pmmoNivmuestraa2Meta));
    }
    if (data.containsKey('pmmo_nivmuestraa3')) {
      context.handle(
          _pmmoNivmuestraa3Meta,
          pmmoNivmuestraa3.isAcceptableOrUnknown(
              data['pmmo_nivmuestraa3']!, _pmmoNivmuestraa3Meta));
    }
    if (data.containsKey('pmmo_nivmuestram1')) {
      context.handle(
          _pmmoNivmuestram1Meta,
          pmmoNivmuestram1.isAcceptableOrUnknown(
              data['pmmo_nivmuestram1']!, _pmmoNivmuestram1Meta));
    }
    if (data.containsKey('pmmo_nivmuestram2')) {
      context.handle(
          _pmmoNivmuestram2Meta,
          pmmoNivmuestram2.isAcceptableOrUnknown(
              data['pmmo_nivmuestram2']!, _pmmoNivmuestram2Meta));
    }
    if (data.containsKey('pmmo_nivmuestram3')) {
      context.handle(
          _pmmoNivmuestram3Meta,
          pmmoNivmuestram3.isAcceptableOrUnknown(
              data['pmmo_nivmuestram3']!, _pmmoNivmuestram3Meta));
    }
    if (data.containsKey('lmsupniv1')) {
      context.handle(_lmsupniv1Meta,
          lmsupniv1.isAcceptableOrUnknown(data['lmsupniv1']!, _lmsupniv1Meta));
    }
    if (data.containsKey('lmsupniv2')) {
      context.handle(_lmsupniv2Meta,
          lmsupniv2.isAcceptableOrUnknown(data['lmsupniv2']!, _lmsupniv2Meta));
    }
    if (data.containsKey('lmsupniv3')) {
      context.handle(_lmsupniv3Meta,
          lmsupniv3.isAcceptableOrUnknown(data['lmsupniv3']!, _lmsupniv3Meta));
    }
    if (data.containsKey('is_local')) {
      context.handle(_isLocalMeta,
          isLocal.isAcceptableOrUnknown(data['is_local']!, _isLocalMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pmmoSecuencia};
  @override
  MonitoreosLocalData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MonitoreosLocalData(
      pmmoSecuencia: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pmmo_secuencia'])!,
      pmltCodigo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pmlt_codigo']),
      pmmoCasa: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pmmo_casa']),
      pmmoCantero: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pmmo_cantero']),
      pmmoCanteros: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pmmo_canteros']),
      pmmoVariedad: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pmmo_variedad']),
      pmmoGrower: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pmmo_grower']),
      pmniNombrecomun: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}pmni_nombrecomun']),
      pmmoCantidad: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pmmo_cantidad']),
      pmmoCantBotada: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pmmo_cant_botada']),
      pmmoComentarios: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}pmmo_comentarios']),
      pmmoFecha: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}pmmo_fecha']),
      pmmoAutomatico: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}pmmo_automatico'])!,
      pmmoEstatus: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pmmo_estatus'])!,
      pmmoCreadopor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pmmo_creadopor']),
      pmmoContenedor: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pmmo_contenedor']),
      pmmoIdvariedad: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pmmo_idvariedad']),
      pmniId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pmni_id']),
      pmmoMuestra1: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pmmo_muestra1']),
      pmmoMuestra2: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pmmo_muestra2']),
      pmmoMuestra3: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pmmo_muestra3']),
      pmmoNivmuestraa1: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pmmo_nivmuestraa1']),
      pmmoNivmuestraa2: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pmmo_nivmuestraa2']),
      pmmoNivmuestraa3: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pmmo_nivmuestraa3']),
      pmmoNivmuestram1: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pmmo_nivmuestram1']),
      pmmoNivmuestram2: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pmmo_nivmuestram2']),
      pmmoNivmuestram3: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pmmo_nivmuestram3']),
      lmsupniv1: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}lmsupniv1']),
      lmsupniv2: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}lmsupniv2']),
      lmsupniv3: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}lmsupniv3']),
      isLocal: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_local'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at']),
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
    );
  }

  @override
  $MonitoreosLocalTable createAlias(String alias) {
    return $MonitoreosLocalTable(attachedDatabase, alias);
  }
}

class MonitoreosLocalData extends DataClass
    implements Insertable<MonitoreosLocalData> {
  final int pmmoSecuencia;
  final String? pmltCodigo;
  final String? pmmoCasa;
  final String? pmmoCantero;
  final String? pmmoCanteros;
  final String? pmmoVariedad;
  final String? pmmoGrower;
  final String? pmniNombrecomun;
  final int? pmmoCantidad;
  final int? pmmoCantBotada;
  final String? pmmoComentarios;
  final DateTime? pmmoFecha;
  final bool pmmoAutomatico;
  final int pmmoEstatus;
  final int? pmmoCreadopor;
  final String? pmmoContenedor;
  final String? pmmoIdvariedad;
  final int? pmniId;
  final int? pmmoMuestra1;
  final int? pmmoMuestra2;
  final int? pmmoMuestra3;
  final int? pmmoNivmuestraa1;
  final int? pmmoNivmuestraa2;
  final int? pmmoNivmuestraa3;
  final int? pmmoNivmuestram1;
  final int? pmmoNivmuestram2;
  final int? pmmoNivmuestram3;
  final int? lmsupniv1;
  final int? lmsupniv2;
  final int? lmsupniv3;
  final bool isLocal;
  final DateTime? syncedAt;
  final int version;
  const MonitoreosLocalData(
      {required this.pmmoSecuencia,
      this.pmltCodigo,
      this.pmmoCasa,
      this.pmmoCantero,
      this.pmmoCanteros,
      this.pmmoVariedad,
      this.pmmoGrower,
      this.pmniNombrecomun,
      this.pmmoCantidad,
      this.pmmoCantBotada,
      this.pmmoComentarios,
      this.pmmoFecha,
      required this.pmmoAutomatico,
      required this.pmmoEstatus,
      this.pmmoCreadopor,
      this.pmmoContenedor,
      this.pmmoIdvariedad,
      this.pmniId,
      this.pmmoMuestra1,
      this.pmmoMuestra2,
      this.pmmoMuestra3,
      this.pmmoNivmuestraa1,
      this.pmmoNivmuestraa2,
      this.pmmoNivmuestraa3,
      this.pmmoNivmuestram1,
      this.pmmoNivmuestram2,
      this.pmmoNivmuestram3,
      this.lmsupniv1,
      this.lmsupniv2,
      this.lmsupniv3,
      required this.isLocal,
      this.syncedAt,
      required this.version});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['pmmo_secuencia'] = Variable<int>(pmmoSecuencia);
    if (!nullToAbsent || pmltCodigo != null) {
      map['pmlt_codigo'] = Variable<String>(pmltCodigo);
    }
    if (!nullToAbsent || pmmoCasa != null) {
      map['pmmo_casa'] = Variable<String>(pmmoCasa);
    }
    if (!nullToAbsent || pmmoCantero != null) {
      map['pmmo_cantero'] = Variable<String>(pmmoCantero);
    }
    if (!nullToAbsent || pmmoCanteros != null) {
      map['pmmo_canteros'] = Variable<String>(pmmoCanteros);
    }
    if (!nullToAbsent || pmmoVariedad != null) {
      map['pmmo_variedad'] = Variable<String>(pmmoVariedad);
    }
    if (!nullToAbsent || pmmoGrower != null) {
      map['pmmo_grower'] = Variable<String>(pmmoGrower);
    }
    if (!nullToAbsent || pmniNombrecomun != null) {
      map['pmni_nombrecomun'] = Variable<String>(pmniNombrecomun);
    }
    if (!nullToAbsent || pmmoCantidad != null) {
      map['pmmo_cantidad'] = Variable<int>(pmmoCantidad);
    }
    if (!nullToAbsent || pmmoCantBotada != null) {
      map['pmmo_cant_botada'] = Variable<int>(pmmoCantBotada);
    }
    if (!nullToAbsent || pmmoComentarios != null) {
      map['pmmo_comentarios'] = Variable<String>(pmmoComentarios);
    }
    if (!nullToAbsent || pmmoFecha != null) {
      map['pmmo_fecha'] = Variable<DateTime>(pmmoFecha);
    }
    map['pmmo_automatico'] = Variable<bool>(pmmoAutomatico);
    map['pmmo_estatus'] = Variable<int>(pmmoEstatus);
    if (!nullToAbsent || pmmoCreadopor != null) {
      map['pmmo_creadopor'] = Variable<int>(pmmoCreadopor);
    }
    if (!nullToAbsent || pmmoContenedor != null) {
      map['pmmo_contenedor'] = Variable<String>(pmmoContenedor);
    }
    if (!nullToAbsent || pmmoIdvariedad != null) {
      map['pmmo_idvariedad'] = Variable<String>(pmmoIdvariedad);
    }
    if (!nullToAbsent || pmniId != null) {
      map['pmni_id'] = Variable<int>(pmniId);
    }
    if (!nullToAbsent || pmmoMuestra1 != null) {
      map['pmmo_muestra1'] = Variable<int>(pmmoMuestra1);
    }
    if (!nullToAbsent || pmmoMuestra2 != null) {
      map['pmmo_muestra2'] = Variable<int>(pmmoMuestra2);
    }
    if (!nullToAbsent || pmmoMuestra3 != null) {
      map['pmmo_muestra3'] = Variable<int>(pmmoMuestra3);
    }
    if (!nullToAbsent || pmmoNivmuestraa1 != null) {
      map['pmmo_nivmuestraa1'] = Variable<int>(pmmoNivmuestraa1);
    }
    if (!nullToAbsent || pmmoNivmuestraa2 != null) {
      map['pmmo_nivmuestraa2'] = Variable<int>(pmmoNivmuestraa2);
    }
    if (!nullToAbsent || pmmoNivmuestraa3 != null) {
      map['pmmo_nivmuestraa3'] = Variable<int>(pmmoNivmuestraa3);
    }
    if (!nullToAbsent || pmmoNivmuestram1 != null) {
      map['pmmo_nivmuestram1'] = Variable<int>(pmmoNivmuestram1);
    }
    if (!nullToAbsent || pmmoNivmuestram2 != null) {
      map['pmmo_nivmuestram2'] = Variable<int>(pmmoNivmuestram2);
    }
    if (!nullToAbsent || pmmoNivmuestram3 != null) {
      map['pmmo_nivmuestram3'] = Variable<int>(pmmoNivmuestram3);
    }
    if (!nullToAbsent || lmsupniv1 != null) {
      map['lmsupniv1'] = Variable<int>(lmsupniv1);
    }
    if (!nullToAbsent || lmsupniv2 != null) {
      map['lmsupniv2'] = Variable<int>(lmsupniv2);
    }
    if (!nullToAbsent || lmsupniv3 != null) {
      map['lmsupniv3'] = Variable<int>(lmsupniv3);
    }
    map['is_local'] = Variable<bool>(isLocal);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    map['version'] = Variable<int>(version);
    return map;
  }

  MonitoreosLocalCompanion toCompanion(bool nullToAbsent) {
    return MonitoreosLocalCompanion(
      pmmoSecuencia: Value(pmmoSecuencia),
      pmltCodigo: pmltCodigo == null && nullToAbsent
          ? const Value.absent()
          : Value(pmltCodigo),
      pmmoCasa: pmmoCasa == null && nullToAbsent
          ? const Value.absent()
          : Value(pmmoCasa),
      pmmoCantero: pmmoCantero == null && nullToAbsent
          ? const Value.absent()
          : Value(pmmoCantero),
      pmmoCanteros: pmmoCanteros == null && nullToAbsent
          ? const Value.absent()
          : Value(pmmoCanteros),
      pmmoVariedad: pmmoVariedad == null && nullToAbsent
          ? const Value.absent()
          : Value(pmmoVariedad),
      pmmoGrower: pmmoGrower == null && nullToAbsent
          ? const Value.absent()
          : Value(pmmoGrower),
      pmniNombrecomun: pmniNombrecomun == null && nullToAbsent
          ? const Value.absent()
          : Value(pmniNombrecomun),
      pmmoCantidad: pmmoCantidad == null && nullToAbsent
          ? const Value.absent()
          : Value(pmmoCantidad),
      pmmoCantBotada: pmmoCantBotada == null && nullToAbsent
          ? const Value.absent()
          : Value(pmmoCantBotada),
      pmmoComentarios: pmmoComentarios == null && nullToAbsent
          ? const Value.absent()
          : Value(pmmoComentarios),
      pmmoFecha: pmmoFecha == null && nullToAbsent
          ? const Value.absent()
          : Value(pmmoFecha),
      pmmoAutomatico: Value(pmmoAutomatico),
      pmmoEstatus: Value(pmmoEstatus),
      pmmoCreadopor: pmmoCreadopor == null && nullToAbsent
          ? const Value.absent()
          : Value(pmmoCreadopor),
      pmmoContenedor: pmmoContenedor == null && nullToAbsent
          ? const Value.absent()
          : Value(pmmoContenedor),
      pmmoIdvariedad: pmmoIdvariedad == null && nullToAbsent
          ? const Value.absent()
          : Value(pmmoIdvariedad),
      pmniId:
          pmniId == null && nullToAbsent ? const Value.absent() : Value(pmniId),
      pmmoMuestra1: pmmoMuestra1 == null && nullToAbsent
          ? const Value.absent()
          : Value(pmmoMuestra1),
      pmmoMuestra2: pmmoMuestra2 == null && nullToAbsent
          ? const Value.absent()
          : Value(pmmoMuestra2),
      pmmoMuestra3: pmmoMuestra3 == null && nullToAbsent
          ? const Value.absent()
          : Value(pmmoMuestra3),
      pmmoNivmuestraa1: pmmoNivmuestraa1 == null && nullToAbsent
          ? const Value.absent()
          : Value(pmmoNivmuestraa1),
      pmmoNivmuestraa2: pmmoNivmuestraa2 == null && nullToAbsent
          ? const Value.absent()
          : Value(pmmoNivmuestraa2),
      pmmoNivmuestraa3: pmmoNivmuestraa3 == null && nullToAbsent
          ? const Value.absent()
          : Value(pmmoNivmuestraa3),
      pmmoNivmuestram1: pmmoNivmuestram1 == null && nullToAbsent
          ? const Value.absent()
          : Value(pmmoNivmuestram1),
      pmmoNivmuestram2: pmmoNivmuestram2 == null && nullToAbsent
          ? const Value.absent()
          : Value(pmmoNivmuestram2),
      pmmoNivmuestram3: pmmoNivmuestram3 == null && nullToAbsent
          ? const Value.absent()
          : Value(pmmoNivmuestram3),
      lmsupniv1: lmsupniv1 == null && nullToAbsent
          ? const Value.absent()
          : Value(lmsupniv1),
      lmsupniv2: lmsupniv2 == null && nullToAbsent
          ? const Value.absent()
          : Value(lmsupniv2),
      lmsupniv3: lmsupniv3 == null && nullToAbsent
          ? const Value.absent()
          : Value(lmsupniv3),
      isLocal: Value(isLocal),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      version: Value(version),
    );
  }

  factory MonitoreosLocalData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MonitoreosLocalData(
      pmmoSecuencia: serializer.fromJson<int>(json['pmmoSecuencia']),
      pmltCodigo: serializer.fromJson<String?>(json['pmltCodigo']),
      pmmoCasa: serializer.fromJson<String?>(json['pmmoCasa']),
      pmmoCantero: serializer.fromJson<String?>(json['pmmoCantero']),
      pmmoCanteros: serializer.fromJson<String?>(json['pmmoCanteros']),
      pmmoVariedad: serializer.fromJson<String?>(json['pmmoVariedad']),
      pmmoGrower: serializer.fromJson<String?>(json['pmmoGrower']),
      pmniNombrecomun: serializer.fromJson<String?>(json['pmniNombrecomun']),
      pmmoCantidad: serializer.fromJson<int?>(json['pmmoCantidad']),
      pmmoCantBotada: serializer.fromJson<int?>(json['pmmoCantBotada']),
      pmmoComentarios: serializer.fromJson<String?>(json['pmmoComentarios']),
      pmmoFecha: serializer.fromJson<DateTime?>(json['pmmoFecha']),
      pmmoAutomatico: serializer.fromJson<bool>(json['pmmoAutomatico']),
      pmmoEstatus: serializer.fromJson<int>(json['pmmoEstatus']),
      pmmoCreadopor: serializer.fromJson<int?>(json['pmmoCreadopor']),
      pmmoContenedor: serializer.fromJson<String?>(json['pmmoContenedor']),
      pmmoIdvariedad: serializer.fromJson<String?>(json['pmmoIdvariedad']),
      pmniId: serializer.fromJson<int?>(json['pmniId']),
      pmmoMuestra1: serializer.fromJson<int?>(json['pmmoMuestra1']),
      pmmoMuestra2: serializer.fromJson<int?>(json['pmmoMuestra2']),
      pmmoMuestra3: serializer.fromJson<int?>(json['pmmoMuestra3']),
      pmmoNivmuestraa1: serializer.fromJson<int?>(json['pmmoNivmuestraa1']),
      pmmoNivmuestraa2: serializer.fromJson<int?>(json['pmmoNivmuestraa2']),
      pmmoNivmuestraa3: serializer.fromJson<int?>(json['pmmoNivmuestraa3']),
      pmmoNivmuestram1: serializer.fromJson<int?>(json['pmmoNivmuestram1']),
      pmmoNivmuestram2: serializer.fromJson<int?>(json['pmmoNivmuestram2']),
      pmmoNivmuestram3: serializer.fromJson<int?>(json['pmmoNivmuestram3']),
      lmsupniv1: serializer.fromJson<int?>(json['lmsupniv1']),
      lmsupniv2: serializer.fromJson<int?>(json['lmsupniv2']),
      lmsupniv3: serializer.fromJson<int?>(json['lmsupniv3']),
      isLocal: serializer.fromJson<bool>(json['isLocal']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pmmoSecuencia': serializer.toJson<int>(pmmoSecuencia),
      'pmltCodigo': serializer.toJson<String?>(pmltCodigo),
      'pmmoCasa': serializer.toJson<String?>(pmmoCasa),
      'pmmoCantero': serializer.toJson<String?>(pmmoCantero),
      'pmmoCanteros': serializer.toJson<String?>(pmmoCanteros),
      'pmmoVariedad': serializer.toJson<String?>(pmmoVariedad),
      'pmmoGrower': serializer.toJson<String?>(pmmoGrower),
      'pmniNombrecomun': serializer.toJson<String?>(pmniNombrecomun),
      'pmmoCantidad': serializer.toJson<int?>(pmmoCantidad),
      'pmmoCantBotada': serializer.toJson<int?>(pmmoCantBotada),
      'pmmoComentarios': serializer.toJson<String?>(pmmoComentarios),
      'pmmoFecha': serializer.toJson<DateTime?>(pmmoFecha),
      'pmmoAutomatico': serializer.toJson<bool>(pmmoAutomatico),
      'pmmoEstatus': serializer.toJson<int>(pmmoEstatus),
      'pmmoCreadopor': serializer.toJson<int?>(pmmoCreadopor),
      'pmmoContenedor': serializer.toJson<String?>(pmmoContenedor),
      'pmmoIdvariedad': serializer.toJson<String?>(pmmoIdvariedad),
      'pmniId': serializer.toJson<int?>(pmniId),
      'pmmoMuestra1': serializer.toJson<int?>(pmmoMuestra1),
      'pmmoMuestra2': serializer.toJson<int?>(pmmoMuestra2),
      'pmmoMuestra3': serializer.toJson<int?>(pmmoMuestra3),
      'pmmoNivmuestraa1': serializer.toJson<int?>(pmmoNivmuestraa1),
      'pmmoNivmuestraa2': serializer.toJson<int?>(pmmoNivmuestraa2),
      'pmmoNivmuestraa3': serializer.toJson<int?>(pmmoNivmuestraa3),
      'pmmoNivmuestram1': serializer.toJson<int?>(pmmoNivmuestram1),
      'pmmoNivmuestram2': serializer.toJson<int?>(pmmoNivmuestram2),
      'pmmoNivmuestram3': serializer.toJson<int?>(pmmoNivmuestram3),
      'lmsupniv1': serializer.toJson<int?>(lmsupniv1),
      'lmsupniv2': serializer.toJson<int?>(lmsupniv2),
      'lmsupniv3': serializer.toJson<int?>(lmsupniv3),
      'isLocal': serializer.toJson<bool>(isLocal),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'version': serializer.toJson<int>(version),
    };
  }

  MonitoreosLocalData copyWith(
          {int? pmmoSecuencia,
          Value<String?> pmltCodigo = const Value.absent(),
          Value<String?> pmmoCasa = const Value.absent(),
          Value<String?> pmmoCantero = const Value.absent(),
          Value<String?> pmmoCanteros = const Value.absent(),
          Value<String?> pmmoVariedad = const Value.absent(),
          Value<String?> pmmoGrower = const Value.absent(),
          Value<String?> pmniNombrecomun = const Value.absent(),
          Value<int?> pmmoCantidad = const Value.absent(),
          Value<int?> pmmoCantBotada = const Value.absent(),
          Value<String?> pmmoComentarios = const Value.absent(),
          Value<DateTime?> pmmoFecha = const Value.absent(),
          bool? pmmoAutomatico,
          int? pmmoEstatus,
          Value<int?> pmmoCreadopor = const Value.absent(),
          Value<String?> pmmoContenedor = const Value.absent(),
          Value<String?> pmmoIdvariedad = const Value.absent(),
          Value<int?> pmniId = const Value.absent(),
          Value<int?> pmmoMuestra1 = const Value.absent(),
          Value<int?> pmmoMuestra2 = const Value.absent(),
          Value<int?> pmmoMuestra3 = const Value.absent(),
          Value<int?> pmmoNivmuestraa1 = const Value.absent(),
          Value<int?> pmmoNivmuestraa2 = const Value.absent(),
          Value<int?> pmmoNivmuestraa3 = const Value.absent(),
          Value<int?> pmmoNivmuestram1 = const Value.absent(),
          Value<int?> pmmoNivmuestram2 = const Value.absent(),
          Value<int?> pmmoNivmuestram3 = const Value.absent(),
          Value<int?> lmsupniv1 = const Value.absent(),
          Value<int?> lmsupniv2 = const Value.absent(),
          Value<int?> lmsupniv3 = const Value.absent(),
          bool? isLocal,
          Value<DateTime?> syncedAt = const Value.absent(),
          int? version}) =>
      MonitoreosLocalData(
        pmmoSecuencia: pmmoSecuencia ?? this.pmmoSecuencia,
        pmltCodigo: pmltCodigo.present ? pmltCodigo.value : this.pmltCodigo,
        pmmoCasa: pmmoCasa.present ? pmmoCasa.value : this.pmmoCasa,
        pmmoCantero: pmmoCantero.present ? pmmoCantero.value : this.pmmoCantero,
        pmmoCanteros:
            pmmoCanteros.present ? pmmoCanteros.value : this.pmmoCanteros,
        pmmoVariedad:
            pmmoVariedad.present ? pmmoVariedad.value : this.pmmoVariedad,
        pmmoGrower: pmmoGrower.present ? pmmoGrower.value : this.pmmoGrower,
        pmniNombrecomun: pmniNombrecomun.present
            ? pmniNombrecomun.value
            : this.pmniNombrecomun,
        pmmoCantidad:
            pmmoCantidad.present ? pmmoCantidad.value : this.pmmoCantidad,
        pmmoCantBotada:
            pmmoCantBotada.present ? pmmoCantBotada.value : this.pmmoCantBotada,
        pmmoComentarios: pmmoComentarios.present
            ? pmmoComentarios.value
            : this.pmmoComentarios,
        pmmoFecha: pmmoFecha.present ? pmmoFecha.value : this.pmmoFecha,
        pmmoAutomatico: pmmoAutomatico ?? this.pmmoAutomatico,
        pmmoEstatus: pmmoEstatus ?? this.pmmoEstatus,
        pmmoCreadopor:
            pmmoCreadopor.present ? pmmoCreadopor.value : this.pmmoCreadopor,
        pmmoContenedor:
            pmmoContenedor.present ? pmmoContenedor.value : this.pmmoContenedor,
        pmmoIdvariedad:
            pmmoIdvariedad.present ? pmmoIdvariedad.value : this.pmmoIdvariedad,
        pmniId: pmniId.present ? pmniId.value : this.pmniId,
        pmmoMuestra1:
            pmmoMuestra1.present ? pmmoMuestra1.value : this.pmmoMuestra1,
        pmmoMuestra2:
            pmmoMuestra2.present ? pmmoMuestra2.value : this.pmmoMuestra2,
        pmmoMuestra3:
            pmmoMuestra3.present ? pmmoMuestra3.value : this.pmmoMuestra3,
        pmmoNivmuestraa1: pmmoNivmuestraa1.present
            ? pmmoNivmuestraa1.value
            : this.pmmoNivmuestraa1,
        pmmoNivmuestraa2: pmmoNivmuestraa2.present
            ? pmmoNivmuestraa2.value
            : this.pmmoNivmuestraa2,
        pmmoNivmuestraa3: pmmoNivmuestraa3.present
            ? pmmoNivmuestraa3.value
            : this.pmmoNivmuestraa3,
        pmmoNivmuestram1: pmmoNivmuestram1.present
            ? pmmoNivmuestram1.value
            : this.pmmoNivmuestram1,
        pmmoNivmuestram2: pmmoNivmuestram2.present
            ? pmmoNivmuestram2.value
            : this.pmmoNivmuestram2,
        pmmoNivmuestram3: pmmoNivmuestram3.present
            ? pmmoNivmuestram3.value
            : this.pmmoNivmuestram3,
        lmsupniv1: lmsupniv1.present ? lmsupniv1.value : this.lmsupniv1,
        lmsupniv2: lmsupniv2.present ? lmsupniv2.value : this.lmsupniv2,
        lmsupniv3: lmsupniv3.present ? lmsupniv3.value : this.lmsupniv3,
        isLocal: isLocal ?? this.isLocal,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
        version: version ?? this.version,
      );
  MonitoreosLocalData copyWithCompanion(MonitoreosLocalCompanion data) {
    return MonitoreosLocalData(
      pmmoSecuencia: data.pmmoSecuencia.present
          ? data.pmmoSecuencia.value
          : this.pmmoSecuencia,
      pmltCodigo:
          data.pmltCodigo.present ? data.pmltCodigo.value : this.pmltCodigo,
      pmmoCasa: data.pmmoCasa.present ? data.pmmoCasa.value : this.pmmoCasa,
      pmmoCantero:
          data.pmmoCantero.present ? data.pmmoCantero.value : this.pmmoCantero,
      pmmoCanteros: data.pmmoCanteros.present
          ? data.pmmoCanteros.value
          : this.pmmoCanteros,
      pmmoVariedad: data.pmmoVariedad.present
          ? data.pmmoVariedad.value
          : this.pmmoVariedad,
      pmmoGrower:
          data.pmmoGrower.present ? data.pmmoGrower.value : this.pmmoGrower,
      pmniNombrecomun: data.pmniNombrecomun.present
          ? data.pmniNombrecomun.value
          : this.pmniNombrecomun,
      pmmoCantidad: data.pmmoCantidad.present
          ? data.pmmoCantidad.value
          : this.pmmoCantidad,
      pmmoCantBotada: data.pmmoCantBotada.present
          ? data.pmmoCantBotada.value
          : this.pmmoCantBotada,
      pmmoComentarios: data.pmmoComentarios.present
          ? data.pmmoComentarios.value
          : this.pmmoComentarios,
      pmmoFecha: data.pmmoFecha.present ? data.pmmoFecha.value : this.pmmoFecha,
      pmmoAutomatico: data.pmmoAutomatico.present
          ? data.pmmoAutomatico.value
          : this.pmmoAutomatico,
      pmmoEstatus:
          data.pmmoEstatus.present ? data.pmmoEstatus.value : this.pmmoEstatus,
      pmmoCreadopor: data.pmmoCreadopor.present
          ? data.pmmoCreadopor.value
          : this.pmmoCreadopor,
      pmmoContenedor: data.pmmoContenedor.present
          ? data.pmmoContenedor.value
          : this.pmmoContenedor,
      pmmoIdvariedad: data.pmmoIdvariedad.present
          ? data.pmmoIdvariedad.value
          : this.pmmoIdvariedad,
      pmniId: data.pmniId.present ? data.pmniId.value : this.pmniId,
      pmmoMuestra1: data.pmmoMuestra1.present
          ? data.pmmoMuestra1.value
          : this.pmmoMuestra1,
      pmmoMuestra2: data.pmmoMuestra2.present
          ? data.pmmoMuestra2.value
          : this.pmmoMuestra2,
      pmmoMuestra3: data.pmmoMuestra3.present
          ? data.pmmoMuestra3.value
          : this.pmmoMuestra3,
      pmmoNivmuestraa1: data.pmmoNivmuestraa1.present
          ? data.pmmoNivmuestraa1.value
          : this.pmmoNivmuestraa1,
      pmmoNivmuestraa2: data.pmmoNivmuestraa2.present
          ? data.pmmoNivmuestraa2.value
          : this.pmmoNivmuestraa2,
      pmmoNivmuestraa3: data.pmmoNivmuestraa3.present
          ? data.pmmoNivmuestraa3.value
          : this.pmmoNivmuestraa3,
      pmmoNivmuestram1: data.pmmoNivmuestram1.present
          ? data.pmmoNivmuestram1.value
          : this.pmmoNivmuestram1,
      pmmoNivmuestram2: data.pmmoNivmuestram2.present
          ? data.pmmoNivmuestram2.value
          : this.pmmoNivmuestram2,
      pmmoNivmuestram3: data.pmmoNivmuestram3.present
          ? data.pmmoNivmuestram3.value
          : this.pmmoNivmuestram3,
      lmsupniv1: data.lmsupniv1.present ? data.lmsupniv1.value : this.lmsupniv1,
      lmsupniv2: data.lmsupniv2.present ? data.lmsupniv2.value : this.lmsupniv2,
      lmsupniv3: data.lmsupniv3.present ? data.lmsupniv3.value : this.lmsupniv3,
      isLocal: data.isLocal.present ? data.isLocal.value : this.isLocal,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MonitoreosLocalData(')
          ..write('pmmoSecuencia: $pmmoSecuencia, ')
          ..write('pmltCodigo: $pmltCodigo, ')
          ..write('pmmoCasa: $pmmoCasa, ')
          ..write('pmmoCantero: $pmmoCantero, ')
          ..write('pmmoCanteros: $pmmoCanteros, ')
          ..write('pmmoVariedad: $pmmoVariedad, ')
          ..write('pmmoGrower: $pmmoGrower, ')
          ..write('pmniNombrecomun: $pmniNombrecomun, ')
          ..write('pmmoCantidad: $pmmoCantidad, ')
          ..write('pmmoCantBotada: $pmmoCantBotada, ')
          ..write('pmmoComentarios: $pmmoComentarios, ')
          ..write('pmmoFecha: $pmmoFecha, ')
          ..write('pmmoAutomatico: $pmmoAutomatico, ')
          ..write('pmmoEstatus: $pmmoEstatus, ')
          ..write('pmmoCreadopor: $pmmoCreadopor, ')
          ..write('pmmoContenedor: $pmmoContenedor, ')
          ..write('pmmoIdvariedad: $pmmoIdvariedad, ')
          ..write('pmniId: $pmniId, ')
          ..write('pmmoMuestra1: $pmmoMuestra1, ')
          ..write('pmmoMuestra2: $pmmoMuestra2, ')
          ..write('pmmoMuestra3: $pmmoMuestra3, ')
          ..write('pmmoNivmuestraa1: $pmmoNivmuestraa1, ')
          ..write('pmmoNivmuestraa2: $pmmoNivmuestraa2, ')
          ..write('pmmoNivmuestraa3: $pmmoNivmuestraa3, ')
          ..write('pmmoNivmuestram1: $pmmoNivmuestram1, ')
          ..write('pmmoNivmuestram2: $pmmoNivmuestram2, ')
          ..write('pmmoNivmuestram3: $pmmoNivmuestram3, ')
          ..write('lmsupniv1: $lmsupniv1, ')
          ..write('lmsupniv2: $lmsupniv2, ')
          ..write('lmsupniv3: $lmsupniv3, ')
          ..write('isLocal: $isLocal, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        pmmoSecuencia,
        pmltCodigo,
        pmmoCasa,
        pmmoCantero,
        pmmoCanteros,
        pmmoVariedad,
        pmmoGrower,
        pmniNombrecomun,
        pmmoCantidad,
        pmmoCantBotada,
        pmmoComentarios,
        pmmoFecha,
        pmmoAutomatico,
        pmmoEstatus,
        pmmoCreadopor,
        pmmoContenedor,
        pmmoIdvariedad,
        pmniId,
        pmmoMuestra1,
        pmmoMuestra2,
        pmmoMuestra3,
        pmmoNivmuestraa1,
        pmmoNivmuestraa2,
        pmmoNivmuestraa3,
        pmmoNivmuestram1,
        pmmoNivmuestram2,
        pmmoNivmuestram3,
        lmsupniv1,
        lmsupniv2,
        lmsupniv3,
        isLocal,
        syncedAt,
        version
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MonitoreosLocalData &&
          other.pmmoSecuencia == this.pmmoSecuencia &&
          other.pmltCodigo == this.pmltCodigo &&
          other.pmmoCasa == this.pmmoCasa &&
          other.pmmoCantero == this.pmmoCantero &&
          other.pmmoCanteros == this.pmmoCanteros &&
          other.pmmoVariedad == this.pmmoVariedad &&
          other.pmmoGrower == this.pmmoGrower &&
          other.pmniNombrecomun == this.pmniNombrecomun &&
          other.pmmoCantidad == this.pmmoCantidad &&
          other.pmmoCantBotada == this.pmmoCantBotada &&
          other.pmmoComentarios == this.pmmoComentarios &&
          other.pmmoFecha == this.pmmoFecha &&
          other.pmmoAutomatico == this.pmmoAutomatico &&
          other.pmmoEstatus == this.pmmoEstatus &&
          other.pmmoCreadopor == this.pmmoCreadopor &&
          other.pmmoContenedor == this.pmmoContenedor &&
          other.pmmoIdvariedad == this.pmmoIdvariedad &&
          other.pmniId == this.pmniId &&
          other.pmmoMuestra1 == this.pmmoMuestra1 &&
          other.pmmoMuestra2 == this.pmmoMuestra2 &&
          other.pmmoMuestra3 == this.pmmoMuestra3 &&
          other.pmmoNivmuestraa1 == this.pmmoNivmuestraa1 &&
          other.pmmoNivmuestraa2 == this.pmmoNivmuestraa2 &&
          other.pmmoNivmuestraa3 == this.pmmoNivmuestraa3 &&
          other.pmmoNivmuestram1 == this.pmmoNivmuestram1 &&
          other.pmmoNivmuestram2 == this.pmmoNivmuestram2 &&
          other.pmmoNivmuestram3 == this.pmmoNivmuestram3 &&
          other.lmsupniv1 == this.lmsupniv1 &&
          other.lmsupniv2 == this.lmsupniv2 &&
          other.lmsupniv3 == this.lmsupniv3 &&
          other.isLocal == this.isLocal &&
          other.syncedAt == this.syncedAt &&
          other.version == this.version);
}

class MonitoreosLocalCompanion extends UpdateCompanion<MonitoreosLocalData> {
  final Value<int> pmmoSecuencia;
  final Value<String?> pmltCodigo;
  final Value<String?> pmmoCasa;
  final Value<String?> pmmoCantero;
  final Value<String?> pmmoCanteros;
  final Value<String?> pmmoVariedad;
  final Value<String?> pmmoGrower;
  final Value<String?> pmniNombrecomun;
  final Value<int?> pmmoCantidad;
  final Value<int?> pmmoCantBotada;
  final Value<String?> pmmoComentarios;
  final Value<DateTime?> pmmoFecha;
  final Value<bool> pmmoAutomatico;
  final Value<int> pmmoEstatus;
  final Value<int?> pmmoCreadopor;
  final Value<String?> pmmoContenedor;
  final Value<String?> pmmoIdvariedad;
  final Value<int?> pmniId;
  final Value<int?> pmmoMuestra1;
  final Value<int?> pmmoMuestra2;
  final Value<int?> pmmoMuestra3;
  final Value<int?> pmmoNivmuestraa1;
  final Value<int?> pmmoNivmuestraa2;
  final Value<int?> pmmoNivmuestraa3;
  final Value<int?> pmmoNivmuestram1;
  final Value<int?> pmmoNivmuestram2;
  final Value<int?> pmmoNivmuestram3;
  final Value<int?> lmsupniv1;
  final Value<int?> lmsupniv2;
  final Value<int?> lmsupniv3;
  final Value<bool> isLocal;
  final Value<DateTime?> syncedAt;
  final Value<int> version;
  const MonitoreosLocalCompanion({
    this.pmmoSecuencia = const Value.absent(),
    this.pmltCodigo = const Value.absent(),
    this.pmmoCasa = const Value.absent(),
    this.pmmoCantero = const Value.absent(),
    this.pmmoCanteros = const Value.absent(),
    this.pmmoVariedad = const Value.absent(),
    this.pmmoGrower = const Value.absent(),
    this.pmniNombrecomun = const Value.absent(),
    this.pmmoCantidad = const Value.absent(),
    this.pmmoCantBotada = const Value.absent(),
    this.pmmoComentarios = const Value.absent(),
    this.pmmoFecha = const Value.absent(),
    this.pmmoAutomatico = const Value.absent(),
    this.pmmoEstatus = const Value.absent(),
    this.pmmoCreadopor = const Value.absent(),
    this.pmmoContenedor = const Value.absent(),
    this.pmmoIdvariedad = const Value.absent(),
    this.pmniId = const Value.absent(),
    this.pmmoMuestra1 = const Value.absent(),
    this.pmmoMuestra2 = const Value.absent(),
    this.pmmoMuestra3 = const Value.absent(),
    this.pmmoNivmuestraa1 = const Value.absent(),
    this.pmmoNivmuestraa2 = const Value.absent(),
    this.pmmoNivmuestraa3 = const Value.absent(),
    this.pmmoNivmuestram1 = const Value.absent(),
    this.pmmoNivmuestram2 = const Value.absent(),
    this.pmmoNivmuestram3 = const Value.absent(),
    this.lmsupniv1 = const Value.absent(),
    this.lmsupniv2 = const Value.absent(),
    this.lmsupniv3 = const Value.absent(),
    this.isLocal = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.version = const Value.absent(),
  });
  MonitoreosLocalCompanion.insert({
    this.pmmoSecuencia = const Value.absent(),
    this.pmltCodigo = const Value.absent(),
    this.pmmoCasa = const Value.absent(),
    this.pmmoCantero = const Value.absent(),
    this.pmmoCanteros = const Value.absent(),
    this.pmmoVariedad = const Value.absent(),
    this.pmmoGrower = const Value.absent(),
    this.pmniNombrecomun = const Value.absent(),
    this.pmmoCantidad = const Value.absent(),
    this.pmmoCantBotada = const Value.absent(),
    this.pmmoComentarios = const Value.absent(),
    this.pmmoFecha = const Value.absent(),
    this.pmmoAutomatico = const Value.absent(),
    this.pmmoEstatus = const Value.absent(),
    this.pmmoCreadopor = const Value.absent(),
    this.pmmoContenedor = const Value.absent(),
    this.pmmoIdvariedad = const Value.absent(),
    this.pmniId = const Value.absent(),
    this.pmmoMuestra1 = const Value.absent(),
    this.pmmoMuestra2 = const Value.absent(),
    this.pmmoMuestra3 = const Value.absent(),
    this.pmmoNivmuestraa1 = const Value.absent(),
    this.pmmoNivmuestraa2 = const Value.absent(),
    this.pmmoNivmuestraa3 = const Value.absent(),
    this.pmmoNivmuestram1 = const Value.absent(),
    this.pmmoNivmuestram2 = const Value.absent(),
    this.pmmoNivmuestram3 = const Value.absent(),
    this.lmsupniv1 = const Value.absent(),
    this.lmsupniv2 = const Value.absent(),
    this.lmsupniv3 = const Value.absent(),
    this.isLocal = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.version = const Value.absent(),
  });
  static Insertable<MonitoreosLocalData> custom({
    Expression<int>? pmmoSecuencia,
    Expression<String>? pmltCodigo,
    Expression<String>? pmmoCasa,
    Expression<String>? pmmoCantero,
    Expression<String>? pmmoCanteros,
    Expression<String>? pmmoVariedad,
    Expression<String>? pmmoGrower,
    Expression<String>? pmniNombrecomun,
    Expression<int>? pmmoCantidad,
    Expression<int>? pmmoCantBotada,
    Expression<String>? pmmoComentarios,
    Expression<DateTime>? pmmoFecha,
    Expression<bool>? pmmoAutomatico,
    Expression<int>? pmmoEstatus,
    Expression<int>? pmmoCreadopor,
    Expression<String>? pmmoContenedor,
    Expression<String>? pmmoIdvariedad,
    Expression<int>? pmniId,
    Expression<int>? pmmoMuestra1,
    Expression<int>? pmmoMuestra2,
    Expression<int>? pmmoMuestra3,
    Expression<int>? pmmoNivmuestraa1,
    Expression<int>? pmmoNivmuestraa2,
    Expression<int>? pmmoNivmuestraa3,
    Expression<int>? pmmoNivmuestram1,
    Expression<int>? pmmoNivmuestram2,
    Expression<int>? pmmoNivmuestram3,
    Expression<int>? lmsupniv1,
    Expression<int>? lmsupniv2,
    Expression<int>? lmsupniv3,
    Expression<bool>? isLocal,
    Expression<DateTime>? syncedAt,
    Expression<int>? version,
  }) {
    return RawValuesInsertable({
      if (pmmoSecuencia != null) 'pmmo_secuencia': pmmoSecuencia,
      if (pmltCodigo != null) 'pmlt_codigo': pmltCodigo,
      if (pmmoCasa != null) 'pmmo_casa': pmmoCasa,
      if (pmmoCantero != null) 'pmmo_cantero': pmmoCantero,
      if (pmmoCanteros != null) 'pmmo_canteros': pmmoCanteros,
      if (pmmoVariedad != null) 'pmmo_variedad': pmmoVariedad,
      if (pmmoGrower != null) 'pmmo_grower': pmmoGrower,
      if (pmniNombrecomun != null) 'pmni_nombrecomun': pmniNombrecomun,
      if (pmmoCantidad != null) 'pmmo_cantidad': pmmoCantidad,
      if (pmmoCantBotada != null) 'pmmo_cant_botada': pmmoCantBotada,
      if (pmmoComentarios != null) 'pmmo_comentarios': pmmoComentarios,
      if (pmmoFecha != null) 'pmmo_fecha': pmmoFecha,
      if (pmmoAutomatico != null) 'pmmo_automatico': pmmoAutomatico,
      if (pmmoEstatus != null) 'pmmo_estatus': pmmoEstatus,
      if (pmmoCreadopor != null) 'pmmo_creadopor': pmmoCreadopor,
      if (pmmoContenedor != null) 'pmmo_contenedor': pmmoContenedor,
      if (pmmoIdvariedad != null) 'pmmo_idvariedad': pmmoIdvariedad,
      if (pmniId != null) 'pmni_id': pmniId,
      if (pmmoMuestra1 != null) 'pmmo_muestra1': pmmoMuestra1,
      if (pmmoMuestra2 != null) 'pmmo_muestra2': pmmoMuestra2,
      if (pmmoMuestra3 != null) 'pmmo_muestra3': pmmoMuestra3,
      if (pmmoNivmuestraa1 != null) 'pmmo_nivmuestraa1': pmmoNivmuestraa1,
      if (pmmoNivmuestraa2 != null) 'pmmo_nivmuestraa2': pmmoNivmuestraa2,
      if (pmmoNivmuestraa3 != null) 'pmmo_nivmuestraa3': pmmoNivmuestraa3,
      if (pmmoNivmuestram1 != null) 'pmmo_nivmuestram1': pmmoNivmuestram1,
      if (pmmoNivmuestram2 != null) 'pmmo_nivmuestram2': pmmoNivmuestram2,
      if (pmmoNivmuestram3 != null) 'pmmo_nivmuestram3': pmmoNivmuestram3,
      if (lmsupniv1 != null) 'lmsupniv1': lmsupniv1,
      if (lmsupniv2 != null) 'lmsupniv2': lmsupniv2,
      if (lmsupniv3 != null) 'lmsupniv3': lmsupniv3,
      if (isLocal != null) 'is_local': isLocal,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (version != null) 'version': version,
    });
  }

  MonitoreosLocalCompanion copyWith(
      {Value<int>? pmmoSecuencia,
      Value<String?>? pmltCodigo,
      Value<String?>? pmmoCasa,
      Value<String?>? pmmoCantero,
      Value<String?>? pmmoCanteros,
      Value<String?>? pmmoVariedad,
      Value<String?>? pmmoGrower,
      Value<String?>? pmniNombrecomun,
      Value<int?>? pmmoCantidad,
      Value<int?>? pmmoCantBotada,
      Value<String?>? pmmoComentarios,
      Value<DateTime?>? pmmoFecha,
      Value<bool>? pmmoAutomatico,
      Value<int>? pmmoEstatus,
      Value<int?>? pmmoCreadopor,
      Value<String?>? pmmoContenedor,
      Value<String?>? pmmoIdvariedad,
      Value<int?>? pmniId,
      Value<int?>? pmmoMuestra1,
      Value<int?>? pmmoMuestra2,
      Value<int?>? pmmoMuestra3,
      Value<int?>? pmmoNivmuestraa1,
      Value<int?>? pmmoNivmuestraa2,
      Value<int?>? pmmoNivmuestraa3,
      Value<int?>? pmmoNivmuestram1,
      Value<int?>? pmmoNivmuestram2,
      Value<int?>? pmmoNivmuestram3,
      Value<int?>? lmsupniv1,
      Value<int?>? lmsupniv2,
      Value<int?>? lmsupniv3,
      Value<bool>? isLocal,
      Value<DateTime?>? syncedAt,
      Value<int>? version}) {
    return MonitoreosLocalCompanion(
      pmmoSecuencia: pmmoSecuencia ?? this.pmmoSecuencia,
      pmltCodigo: pmltCodigo ?? this.pmltCodigo,
      pmmoCasa: pmmoCasa ?? this.pmmoCasa,
      pmmoCantero: pmmoCantero ?? this.pmmoCantero,
      pmmoCanteros: pmmoCanteros ?? this.pmmoCanteros,
      pmmoVariedad: pmmoVariedad ?? this.pmmoVariedad,
      pmmoGrower: pmmoGrower ?? this.pmmoGrower,
      pmniNombrecomun: pmniNombrecomun ?? this.pmniNombrecomun,
      pmmoCantidad: pmmoCantidad ?? this.pmmoCantidad,
      pmmoCantBotada: pmmoCantBotada ?? this.pmmoCantBotada,
      pmmoComentarios: pmmoComentarios ?? this.pmmoComentarios,
      pmmoFecha: pmmoFecha ?? this.pmmoFecha,
      pmmoAutomatico: pmmoAutomatico ?? this.pmmoAutomatico,
      pmmoEstatus: pmmoEstatus ?? this.pmmoEstatus,
      pmmoCreadopor: pmmoCreadopor ?? this.pmmoCreadopor,
      pmmoContenedor: pmmoContenedor ?? this.pmmoContenedor,
      pmmoIdvariedad: pmmoIdvariedad ?? this.pmmoIdvariedad,
      pmniId: pmniId ?? this.pmniId,
      pmmoMuestra1: pmmoMuestra1 ?? this.pmmoMuestra1,
      pmmoMuestra2: pmmoMuestra2 ?? this.pmmoMuestra2,
      pmmoMuestra3: pmmoMuestra3 ?? this.pmmoMuestra3,
      pmmoNivmuestraa1: pmmoNivmuestraa1 ?? this.pmmoNivmuestraa1,
      pmmoNivmuestraa2: pmmoNivmuestraa2 ?? this.pmmoNivmuestraa2,
      pmmoNivmuestraa3: pmmoNivmuestraa3 ?? this.pmmoNivmuestraa3,
      pmmoNivmuestram1: pmmoNivmuestram1 ?? this.pmmoNivmuestram1,
      pmmoNivmuestram2: pmmoNivmuestram2 ?? this.pmmoNivmuestram2,
      pmmoNivmuestram3: pmmoNivmuestram3 ?? this.pmmoNivmuestram3,
      lmsupniv1: lmsupniv1 ?? this.lmsupniv1,
      lmsupniv2: lmsupniv2 ?? this.lmsupniv2,
      lmsupniv3: lmsupniv3 ?? this.lmsupniv3,
      isLocal: isLocal ?? this.isLocal,
      syncedAt: syncedAt ?? this.syncedAt,
      version: version ?? this.version,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pmmoSecuencia.present) {
      map['pmmo_secuencia'] = Variable<int>(pmmoSecuencia.value);
    }
    if (pmltCodigo.present) {
      map['pmlt_codigo'] = Variable<String>(pmltCodigo.value);
    }
    if (pmmoCasa.present) {
      map['pmmo_casa'] = Variable<String>(pmmoCasa.value);
    }
    if (pmmoCantero.present) {
      map['pmmo_cantero'] = Variable<String>(pmmoCantero.value);
    }
    if (pmmoCanteros.present) {
      map['pmmo_canteros'] = Variable<String>(pmmoCanteros.value);
    }
    if (pmmoVariedad.present) {
      map['pmmo_variedad'] = Variable<String>(pmmoVariedad.value);
    }
    if (pmmoGrower.present) {
      map['pmmo_grower'] = Variable<String>(pmmoGrower.value);
    }
    if (pmniNombrecomun.present) {
      map['pmni_nombrecomun'] = Variable<String>(pmniNombrecomun.value);
    }
    if (pmmoCantidad.present) {
      map['pmmo_cantidad'] = Variable<int>(pmmoCantidad.value);
    }
    if (pmmoCantBotada.present) {
      map['pmmo_cant_botada'] = Variable<int>(pmmoCantBotada.value);
    }
    if (pmmoComentarios.present) {
      map['pmmo_comentarios'] = Variable<String>(pmmoComentarios.value);
    }
    if (pmmoFecha.present) {
      map['pmmo_fecha'] = Variable<DateTime>(pmmoFecha.value);
    }
    if (pmmoAutomatico.present) {
      map['pmmo_automatico'] = Variable<bool>(pmmoAutomatico.value);
    }
    if (pmmoEstatus.present) {
      map['pmmo_estatus'] = Variable<int>(pmmoEstatus.value);
    }
    if (pmmoCreadopor.present) {
      map['pmmo_creadopor'] = Variable<int>(pmmoCreadopor.value);
    }
    if (pmmoContenedor.present) {
      map['pmmo_contenedor'] = Variable<String>(pmmoContenedor.value);
    }
    if (pmmoIdvariedad.present) {
      map['pmmo_idvariedad'] = Variable<String>(pmmoIdvariedad.value);
    }
    if (pmniId.present) {
      map['pmni_id'] = Variable<int>(pmniId.value);
    }
    if (pmmoMuestra1.present) {
      map['pmmo_muestra1'] = Variable<int>(pmmoMuestra1.value);
    }
    if (pmmoMuestra2.present) {
      map['pmmo_muestra2'] = Variable<int>(pmmoMuestra2.value);
    }
    if (pmmoMuestra3.present) {
      map['pmmo_muestra3'] = Variable<int>(pmmoMuestra3.value);
    }
    if (pmmoNivmuestraa1.present) {
      map['pmmo_nivmuestraa1'] = Variable<int>(pmmoNivmuestraa1.value);
    }
    if (pmmoNivmuestraa2.present) {
      map['pmmo_nivmuestraa2'] = Variable<int>(pmmoNivmuestraa2.value);
    }
    if (pmmoNivmuestraa3.present) {
      map['pmmo_nivmuestraa3'] = Variable<int>(pmmoNivmuestraa3.value);
    }
    if (pmmoNivmuestram1.present) {
      map['pmmo_nivmuestram1'] = Variable<int>(pmmoNivmuestram1.value);
    }
    if (pmmoNivmuestram2.present) {
      map['pmmo_nivmuestram2'] = Variable<int>(pmmoNivmuestram2.value);
    }
    if (pmmoNivmuestram3.present) {
      map['pmmo_nivmuestram3'] = Variable<int>(pmmoNivmuestram3.value);
    }
    if (lmsupniv1.present) {
      map['lmsupniv1'] = Variable<int>(lmsupniv1.value);
    }
    if (lmsupniv2.present) {
      map['lmsupniv2'] = Variable<int>(lmsupniv2.value);
    }
    if (lmsupniv3.present) {
      map['lmsupniv3'] = Variable<int>(lmsupniv3.value);
    }
    if (isLocal.present) {
      map['is_local'] = Variable<bool>(isLocal.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MonitoreosLocalCompanion(')
          ..write('pmmoSecuencia: $pmmoSecuencia, ')
          ..write('pmltCodigo: $pmltCodigo, ')
          ..write('pmmoCasa: $pmmoCasa, ')
          ..write('pmmoCantero: $pmmoCantero, ')
          ..write('pmmoCanteros: $pmmoCanteros, ')
          ..write('pmmoVariedad: $pmmoVariedad, ')
          ..write('pmmoGrower: $pmmoGrower, ')
          ..write('pmniNombrecomun: $pmniNombrecomun, ')
          ..write('pmmoCantidad: $pmmoCantidad, ')
          ..write('pmmoCantBotada: $pmmoCantBotada, ')
          ..write('pmmoComentarios: $pmmoComentarios, ')
          ..write('pmmoFecha: $pmmoFecha, ')
          ..write('pmmoAutomatico: $pmmoAutomatico, ')
          ..write('pmmoEstatus: $pmmoEstatus, ')
          ..write('pmmoCreadopor: $pmmoCreadopor, ')
          ..write('pmmoContenedor: $pmmoContenedor, ')
          ..write('pmmoIdvariedad: $pmmoIdvariedad, ')
          ..write('pmniId: $pmniId, ')
          ..write('pmmoMuestra1: $pmmoMuestra1, ')
          ..write('pmmoMuestra2: $pmmoMuestra2, ')
          ..write('pmmoMuestra3: $pmmoMuestra3, ')
          ..write('pmmoNivmuestraa1: $pmmoNivmuestraa1, ')
          ..write('pmmoNivmuestraa2: $pmmoNivmuestraa2, ')
          ..write('pmmoNivmuestraa3: $pmmoNivmuestraa3, ')
          ..write('pmmoNivmuestram1: $pmmoNivmuestram1, ')
          ..write('pmmoNivmuestram2: $pmmoNivmuestram2, ')
          ..write('pmmoNivmuestram3: $pmmoNivmuestram3, ')
          ..write('lmsupniv1: $lmsupniv1, ')
          ..write('lmsupniv2: $lmsupniv2, ')
          ..write('lmsupniv3: $lmsupniv3, ')
          ..write('isLocal: $isLocal, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }
}

class $CatalogosTable extends Catalogos
    with TableInfo<$CatalogosTable, Catalogo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _tipoMeta = const VerificationMeta('tipo');
  @override
  late final GeneratedColumn<String> tipo = GeneratedColumn<String>(
      'tipo', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _claveMeta = const VerificationMeta('clave');
  @override
  late final GeneratedColumn<String> clave = GeneratedColumn<String>(
      'clave', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
      'data', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, tipo, clave, data, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalogos';
  @override
  VerificationContext validateIntegrity(Insertable<Catalogo> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tipo')) {
      context.handle(
          _tipoMeta, tipo.isAcceptableOrUnknown(data['tipo']!, _tipoMeta));
    } else if (isInserting) {
      context.missing(_tipoMeta);
    }
    if (data.containsKey('clave')) {
      context.handle(
          _claveMeta, clave.isAcceptableOrUnknown(data['clave']!, _claveMeta));
    }
    if (data.containsKey('data')) {
      context.handle(
          _dataMeta, this.data.isAcceptableOrUnknown(data['data']!, _dataMeta));
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Catalogo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Catalogo(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      tipo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tipo'])!,
      clave: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}clave']),
      data: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $CatalogosTable createAlias(String alias) {
    return $CatalogosTable(attachedDatabase, alias);
  }
}

class Catalogo extends DataClass implements Insertable<Catalogo> {
  final int id;
  final String tipo;
  final String? clave;
  final String data;
  final DateTime updatedAt;
  const Catalogo(
      {required this.id,
      required this.tipo,
      this.clave,
      required this.data,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tipo'] = Variable<String>(tipo);
    if (!nullToAbsent || clave != null) {
      map['clave'] = Variable<String>(clave);
    }
    map['data'] = Variable<String>(data);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CatalogosCompanion toCompanion(bool nullToAbsent) {
    return CatalogosCompanion(
      id: Value(id),
      tipo: Value(tipo),
      clave:
          clave == null && nullToAbsent ? const Value.absent() : Value(clave),
      data: Value(data),
      updatedAt: Value(updatedAt),
    );
  }

  factory Catalogo.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Catalogo(
      id: serializer.fromJson<int>(json['id']),
      tipo: serializer.fromJson<String>(json['tipo']),
      clave: serializer.fromJson<String?>(json['clave']),
      data: serializer.fromJson<String>(json['data']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tipo': serializer.toJson<String>(tipo),
      'clave': serializer.toJson<String?>(clave),
      'data': serializer.toJson<String>(data),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Catalogo copyWith(
          {int? id,
          String? tipo,
          Value<String?> clave = const Value.absent(),
          String? data,
          DateTime? updatedAt}) =>
      Catalogo(
        id: id ?? this.id,
        tipo: tipo ?? this.tipo,
        clave: clave.present ? clave.value : this.clave,
        data: data ?? this.data,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Catalogo copyWithCompanion(CatalogosCompanion data) {
    return Catalogo(
      id: data.id.present ? data.id.value : this.id,
      tipo: data.tipo.present ? data.tipo.value : this.tipo,
      clave: data.clave.present ? data.clave.value : this.clave,
      data: data.data.present ? data.data.value : this.data,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Catalogo(')
          ..write('id: $id, ')
          ..write('tipo: $tipo, ')
          ..write('clave: $clave, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tipo, clave, data, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Catalogo &&
          other.id == this.id &&
          other.tipo == this.tipo &&
          other.clave == this.clave &&
          other.data == this.data &&
          other.updatedAt == this.updatedAt);
}

class CatalogosCompanion extends UpdateCompanion<Catalogo> {
  final Value<int> id;
  final Value<String> tipo;
  final Value<String?> clave;
  final Value<String> data;
  final Value<DateTime> updatedAt;
  const CatalogosCompanion({
    this.id = const Value.absent(),
    this.tipo = const Value.absent(),
    this.clave = const Value.absent(),
    this.data = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  CatalogosCompanion.insert({
    this.id = const Value.absent(),
    required String tipo,
    this.clave = const Value.absent(),
    required String data,
    required DateTime updatedAt,
  })  : tipo = Value(tipo),
        data = Value(data),
        updatedAt = Value(updatedAt);
  static Insertable<Catalogo> custom({
    Expression<int>? id,
    Expression<String>? tipo,
    Expression<String>? clave,
    Expression<String>? data,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tipo != null) 'tipo': tipo,
      if (clave != null) 'clave': clave,
      if (data != null) 'data': data,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  CatalogosCompanion copyWith(
      {Value<int>? id,
      Value<String>? tipo,
      Value<String?>? clave,
      Value<String>? data,
      Value<DateTime>? updatedAt}) {
    return CatalogosCompanion(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      clave: clave ?? this.clave,
      data: data ?? this.data,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tipo.present) {
      map['tipo'] = Variable<String>(tipo.value);
    }
    if (clave.present) {
      map['clave'] = Variable<String>(clave.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogosCompanion(')
          ..write('id: $id, ')
          ..write('tipo: $tipo, ')
          ..write('clave: $clave, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SyncMetadataTable extends SyncMetadata
    with TableInfo<$SyncMetadataTable, SyncMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_metadata';
  @override
  VerificationContext validateIntegrity(Insertable<SyncMetadataData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetadataData(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $SyncMetadataTable createAlias(String alias) {
    return $SyncMetadataTable(attachedDatabase, alias);
  }
}

class SyncMetadataData extends DataClass
    implements Insertable<SyncMetadataData> {
  final String key;
  final String value;
  const SyncMetadataData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncMetadataCompanion toCompanion(bool nullToAbsent) {
    return SyncMetadataCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory SyncMetadataData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetadataData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncMetadataData copyWith({String? key, String? value}) => SyncMetadataData(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  SyncMetadataData copyWithCompanion(SyncMetadataCompanion data) {
    return SyncMetadataData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetadataData &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncMetadataCompanion extends UpdateCompanion<SyncMetadataData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetadataCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<SyncMetadataData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetadataCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return SyncMetadataCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $MonitoreosLocalTable monitoreosLocal =
      $MonitoreosLocalTable(this);
  late final $CatalogosTable catalogos = $CatalogosTable(this);
  late final $SyncMetadataTable syncMetadata = $SyncMetadataTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [outbox, monitoreosLocal, catalogos, syncMetadata];
}

typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  Value<int> id,
  required String idempotencyKey,
  required int userId,
  required String operation,
  required String payload,
  Value<int?> tempId,
  Value<int?> serverId,
  Value<int> retryCount,
  Value<int> maxRetries,
  required DateTime createdAt,
  Value<DateTime?> lastAttempt,
  Value<String> status,
  Value<String?> errorMessage,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<int> id,
  Value<String> idempotencyKey,
  Value<int> userId,
  Value<String> operation,
  Value<String> payload,
  Value<int?> tempId,
  Value<int?> serverId,
  Value<int> retryCount,
  Value<int> maxRetries,
  Value<DateTime> createdAt,
  Value<DateTime?> lastAttempt,
  Value<String> status,
  Value<String?> errorMessage,
});

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
      column: $table.idempotencyKey,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tempId => $composableBuilder(
      column: $table.tempId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get maxRetries => $composableBuilder(
      column: $table.maxRetries, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastAttempt => $composableBuilder(
      column: $table.lastAttempt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => ColumnFilters(column));
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
      column: $table.idempotencyKey,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tempId => $composableBuilder(
      column: $table.tempId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get maxRetries => $composableBuilder(
      column: $table.maxRetries, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastAttempt => $composableBuilder(
      column: $table.lastAttempt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage,
      builder: (column) => ColumnOrderings(column));
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
      column: $table.idempotencyKey, builder: (column) => column);

  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get tempId =>
      $composableBuilder(column: $table.tempId, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => column);

  GeneratedColumn<int> get maxRetries => $composableBuilder(
      column: $table.maxRetries, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttempt => $composableBuilder(
      column: $table.lastAttempt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => column);
}

class $$OutboxTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OutboxTable,
    OutboxData,
    $$OutboxTableFilterComposer,
    $$OutboxTableOrderingComposer,
    $$OutboxTableAnnotationComposer,
    $$OutboxTableCreateCompanionBuilder,
    $$OutboxTableUpdateCompanionBuilder,
    (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
    OutboxData,
    PrefetchHooks Function()> {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> idempotencyKey = const Value.absent(),
            Value<int> userId = const Value.absent(),
            Value<String> operation = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<int?> tempId = const Value.absent(),
            Value<int?> serverId = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<int> maxRetries = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> lastAttempt = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
          }) =>
              OutboxCompanion(
            id: id,
            idempotencyKey: idempotencyKey,
            userId: userId,
            operation: operation,
            payload: payload,
            tempId: tempId,
            serverId: serverId,
            retryCount: retryCount,
            maxRetries: maxRetries,
            createdAt: createdAt,
            lastAttempt: lastAttempt,
            status: status,
            errorMessage: errorMessage,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String idempotencyKey,
            required int userId,
            required String operation,
            required String payload,
            Value<int?> tempId = const Value.absent(),
            Value<int?> serverId = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<int> maxRetries = const Value.absent(),
            required DateTime createdAt,
            Value<DateTime?> lastAttempt = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
          }) =>
              OutboxCompanion.insert(
            id: id,
            idempotencyKey: idempotencyKey,
            userId: userId,
            operation: operation,
            payload: payload,
            tempId: tempId,
            serverId: serverId,
            retryCount: retryCount,
            maxRetries: maxRetries,
            createdAt: createdAt,
            lastAttempt: lastAttempt,
            status: status,
            errorMessage: errorMessage,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OutboxTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OutboxTable,
    OutboxData,
    $$OutboxTableFilterComposer,
    $$OutboxTableOrderingComposer,
    $$OutboxTableAnnotationComposer,
    $$OutboxTableCreateCompanionBuilder,
    $$OutboxTableUpdateCompanionBuilder,
    (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
    OutboxData,
    PrefetchHooks Function()>;
typedef $$MonitoreosLocalTableCreateCompanionBuilder = MonitoreosLocalCompanion
    Function({
  Value<int> pmmoSecuencia,
  Value<String?> pmltCodigo,
  Value<String?> pmmoCasa,
  Value<String?> pmmoCantero,
  Value<String?> pmmoCanteros,
  Value<String?> pmmoVariedad,
  Value<String?> pmmoGrower,
  Value<String?> pmniNombrecomun,
  Value<int?> pmmoCantidad,
  Value<int?> pmmoCantBotada,
  Value<String?> pmmoComentarios,
  Value<DateTime?> pmmoFecha,
  Value<bool> pmmoAutomatico,
  Value<int> pmmoEstatus,
  Value<int?> pmmoCreadopor,
  Value<String?> pmmoContenedor,
  Value<String?> pmmoIdvariedad,
  Value<int?> pmniId,
  Value<int?> pmmoMuestra1,
  Value<int?> pmmoMuestra2,
  Value<int?> pmmoMuestra3,
  Value<int?> pmmoNivmuestraa1,
  Value<int?> pmmoNivmuestraa2,
  Value<int?> pmmoNivmuestraa3,
  Value<int?> pmmoNivmuestram1,
  Value<int?> pmmoNivmuestram2,
  Value<int?> pmmoNivmuestram3,
  Value<int?> lmsupniv1,
  Value<int?> lmsupniv2,
  Value<int?> lmsupniv3,
  Value<bool> isLocal,
  Value<DateTime?> syncedAt,
  Value<int> version,
});
typedef $$MonitoreosLocalTableUpdateCompanionBuilder = MonitoreosLocalCompanion
    Function({
  Value<int> pmmoSecuencia,
  Value<String?> pmltCodigo,
  Value<String?> pmmoCasa,
  Value<String?> pmmoCantero,
  Value<String?> pmmoCanteros,
  Value<String?> pmmoVariedad,
  Value<String?> pmmoGrower,
  Value<String?> pmniNombrecomun,
  Value<int?> pmmoCantidad,
  Value<int?> pmmoCantBotada,
  Value<String?> pmmoComentarios,
  Value<DateTime?> pmmoFecha,
  Value<bool> pmmoAutomatico,
  Value<int> pmmoEstatus,
  Value<int?> pmmoCreadopor,
  Value<String?> pmmoContenedor,
  Value<String?> pmmoIdvariedad,
  Value<int?> pmniId,
  Value<int?> pmmoMuestra1,
  Value<int?> pmmoMuestra2,
  Value<int?> pmmoMuestra3,
  Value<int?> pmmoNivmuestraa1,
  Value<int?> pmmoNivmuestraa2,
  Value<int?> pmmoNivmuestraa3,
  Value<int?> pmmoNivmuestram1,
  Value<int?> pmmoNivmuestram2,
  Value<int?> pmmoNivmuestram3,
  Value<int?> lmsupniv1,
  Value<int?> lmsupniv2,
  Value<int?> lmsupniv3,
  Value<bool> isLocal,
  Value<DateTime?> syncedAt,
  Value<int> version,
});

class $$MonitoreosLocalTableFilterComposer
    extends Composer<_$AppDatabase, $MonitoreosLocalTable> {
  $$MonitoreosLocalTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get pmmoSecuencia => $composableBuilder(
      column: $table.pmmoSecuencia, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pmltCodigo => $composableBuilder(
      column: $table.pmltCodigo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pmmoCasa => $composableBuilder(
      column: $table.pmmoCasa, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pmmoCantero => $composableBuilder(
      column: $table.pmmoCantero, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pmmoCanteros => $composableBuilder(
      column: $table.pmmoCanteros, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pmmoVariedad => $composableBuilder(
      column: $table.pmmoVariedad, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pmmoGrower => $composableBuilder(
      column: $table.pmmoGrower, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pmniNombrecomun => $composableBuilder(
      column: $table.pmniNombrecomun,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pmmoCantidad => $composableBuilder(
      column: $table.pmmoCantidad, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pmmoCantBotada => $composableBuilder(
      column: $table.pmmoCantBotada,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pmmoComentarios => $composableBuilder(
      column: $table.pmmoComentarios,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get pmmoFecha => $composableBuilder(
      column: $table.pmmoFecha, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get pmmoAutomatico => $composableBuilder(
      column: $table.pmmoAutomatico,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pmmoEstatus => $composableBuilder(
      column: $table.pmmoEstatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pmmoCreadopor => $composableBuilder(
      column: $table.pmmoCreadopor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pmmoContenedor => $composableBuilder(
      column: $table.pmmoContenedor,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pmmoIdvariedad => $composableBuilder(
      column: $table.pmmoIdvariedad,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pmniId => $composableBuilder(
      column: $table.pmniId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pmmoMuestra1 => $composableBuilder(
      column: $table.pmmoMuestra1, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pmmoMuestra2 => $composableBuilder(
      column: $table.pmmoMuestra2, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pmmoMuestra3 => $composableBuilder(
      column: $table.pmmoMuestra3, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pmmoNivmuestraa1 => $composableBuilder(
      column: $table.pmmoNivmuestraa1,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pmmoNivmuestraa2 => $composableBuilder(
      column: $table.pmmoNivmuestraa2,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pmmoNivmuestraa3 => $composableBuilder(
      column: $table.pmmoNivmuestraa3,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pmmoNivmuestram1 => $composableBuilder(
      column: $table.pmmoNivmuestram1,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pmmoNivmuestram2 => $composableBuilder(
      column: $table.pmmoNivmuestram2,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pmmoNivmuestram3 => $composableBuilder(
      column: $table.pmmoNivmuestram3,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lmsupniv1 => $composableBuilder(
      column: $table.lmsupniv1, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lmsupniv2 => $composableBuilder(
      column: $table.lmsupniv2, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lmsupniv3 => $composableBuilder(
      column: $table.lmsupniv3, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isLocal => $composableBuilder(
      column: $table.isLocal, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));
}

class $$MonitoreosLocalTableOrderingComposer
    extends Composer<_$AppDatabase, $MonitoreosLocalTable> {
  $$MonitoreosLocalTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get pmmoSecuencia => $composableBuilder(
      column: $table.pmmoSecuencia,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pmltCodigo => $composableBuilder(
      column: $table.pmltCodigo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pmmoCasa => $composableBuilder(
      column: $table.pmmoCasa, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pmmoCantero => $composableBuilder(
      column: $table.pmmoCantero, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pmmoCanteros => $composableBuilder(
      column: $table.pmmoCanteros,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pmmoVariedad => $composableBuilder(
      column: $table.pmmoVariedad,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pmmoGrower => $composableBuilder(
      column: $table.pmmoGrower, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pmniNombrecomun => $composableBuilder(
      column: $table.pmniNombrecomun,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pmmoCantidad => $composableBuilder(
      column: $table.pmmoCantidad,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pmmoCantBotada => $composableBuilder(
      column: $table.pmmoCantBotada,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pmmoComentarios => $composableBuilder(
      column: $table.pmmoComentarios,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get pmmoFecha => $composableBuilder(
      column: $table.pmmoFecha, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get pmmoAutomatico => $composableBuilder(
      column: $table.pmmoAutomatico,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pmmoEstatus => $composableBuilder(
      column: $table.pmmoEstatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pmmoCreadopor => $composableBuilder(
      column: $table.pmmoCreadopor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pmmoContenedor => $composableBuilder(
      column: $table.pmmoContenedor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pmmoIdvariedad => $composableBuilder(
      column: $table.pmmoIdvariedad,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pmniId => $composableBuilder(
      column: $table.pmniId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pmmoMuestra1 => $composableBuilder(
      column: $table.pmmoMuestra1,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pmmoMuestra2 => $composableBuilder(
      column: $table.pmmoMuestra2,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pmmoMuestra3 => $composableBuilder(
      column: $table.pmmoMuestra3,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pmmoNivmuestraa1 => $composableBuilder(
      column: $table.pmmoNivmuestraa1,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pmmoNivmuestraa2 => $composableBuilder(
      column: $table.pmmoNivmuestraa2,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pmmoNivmuestraa3 => $composableBuilder(
      column: $table.pmmoNivmuestraa3,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pmmoNivmuestram1 => $composableBuilder(
      column: $table.pmmoNivmuestram1,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pmmoNivmuestram2 => $composableBuilder(
      column: $table.pmmoNivmuestram2,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pmmoNivmuestram3 => $composableBuilder(
      column: $table.pmmoNivmuestram3,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lmsupniv1 => $composableBuilder(
      column: $table.lmsupniv1, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lmsupniv2 => $composableBuilder(
      column: $table.lmsupniv2, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lmsupniv3 => $composableBuilder(
      column: $table.lmsupniv3, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isLocal => $composableBuilder(
      column: $table.isLocal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));
}

class $$MonitoreosLocalTableAnnotationComposer
    extends Composer<_$AppDatabase, $MonitoreosLocalTable> {
  $$MonitoreosLocalTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get pmmoSecuencia => $composableBuilder(
      column: $table.pmmoSecuencia, builder: (column) => column);

  GeneratedColumn<String> get pmltCodigo => $composableBuilder(
      column: $table.pmltCodigo, builder: (column) => column);

  GeneratedColumn<String> get pmmoCasa =>
      $composableBuilder(column: $table.pmmoCasa, builder: (column) => column);

  GeneratedColumn<String> get pmmoCantero => $composableBuilder(
      column: $table.pmmoCantero, builder: (column) => column);

  GeneratedColumn<String> get pmmoCanteros => $composableBuilder(
      column: $table.pmmoCanteros, builder: (column) => column);

  GeneratedColumn<String> get pmmoVariedad => $composableBuilder(
      column: $table.pmmoVariedad, builder: (column) => column);

  GeneratedColumn<String> get pmmoGrower => $composableBuilder(
      column: $table.pmmoGrower, builder: (column) => column);

  GeneratedColumn<String> get pmniNombrecomun => $composableBuilder(
      column: $table.pmniNombrecomun, builder: (column) => column);

  GeneratedColumn<int> get pmmoCantidad => $composableBuilder(
      column: $table.pmmoCantidad, builder: (column) => column);

  GeneratedColumn<int> get pmmoCantBotada => $composableBuilder(
      column: $table.pmmoCantBotada, builder: (column) => column);

  GeneratedColumn<String> get pmmoComentarios => $composableBuilder(
      column: $table.pmmoComentarios, builder: (column) => column);

  GeneratedColumn<DateTime> get pmmoFecha =>
      $composableBuilder(column: $table.pmmoFecha, builder: (column) => column);

  GeneratedColumn<bool> get pmmoAutomatico => $composableBuilder(
      column: $table.pmmoAutomatico, builder: (column) => column);

  GeneratedColumn<int> get pmmoEstatus => $composableBuilder(
      column: $table.pmmoEstatus, builder: (column) => column);

  GeneratedColumn<int> get pmmoCreadopor => $composableBuilder(
      column: $table.pmmoCreadopor, builder: (column) => column);

  GeneratedColumn<String> get pmmoContenedor => $composableBuilder(
      column: $table.pmmoContenedor, builder: (column) => column);

  GeneratedColumn<String> get pmmoIdvariedad => $composableBuilder(
      column: $table.pmmoIdvariedad, builder: (column) => column);

  GeneratedColumn<int> get pmniId =>
      $composableBuilder(column: $table.pmniId, builder: (column) => column);

  GeneratedColumn<int> get pmmoMuestra1 => $composableBuilder(
      column: $table.pmmoMuestra1, builder: (column) => column);

  GeneratedColumn<int> get pmmoMuestra2 => $composableBuilder(
      column: $table.pmmoMuestra2, builder: (column) => column);

  GeneratedColumn<int> get pmmoMuestra3 => $composableBuilder(
      column: $table.pmmoMuestra3, builder: (column) => column);

  GeneratedColumn<int> get pmmoNivmuestraa1 => $composableBuilder(
      column: $table.pmmoNivmuestraa1, builder: (column) => column);

  GeneratedColumn<int> get pmmoNivmuestraa2 => $composableBuilder(
      column: $table.pmmoNivmuestraa2, builder: (column) => column);

  GeneratedColumn<int> get pmmoNivmuestraa3 => $composableBuilder(
      column: $table.pmmoNivmuestraa3, builder: (column) => column);

  GeneratedColumn<int> get pmmoNivmuestram1 => $composableBuilder(
      column: $table.pmmoNivmuestram1, builder: (column) => column);

  GeneratedColumn<int> get pmmoNivmuestram2 => $composableBuilder(
      column: $table.pmmoNivmuestram2, builder: (column) => column);

  GeneratedColumn<int> get pmmoNivmuestram3 => $composableBuilder(
      column: $table.pmmoNivmuestram3, builder: (column) => column);

  GeneratedColumn<int> get lmsupniv1 =>
      $composableBuilder(column: $table.lmsupniv1, builder: (column) => column);

  GeneratedColumn<int> get lmsupniv2 =>
      $composableBuilder(column: $table.lmsupniv2, builder: (column) => column);

  GeneratedColumn<int> get lmsupniv3 =>
      $composableBuilder(column: $table.lmsupniv3, builder: (column) => column);

  GeneratedColumn<bool> get isLocal =>
      $composableBuilder(column: $table.isLocal, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$MonitoreosLocalTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MonitoreosLocalTable,
    MonitoreosLocalData,
    $$MonitoreosLocalTableFilterComposer,
    $$MonitoreosLocalTableOrderingComposer,
    $$MonitoreosLocalTableAnnotationComposer,
    $$MonitoreosLocalTableCreateCompanionBuilder,
    $$MonitoreosLocalTableUpdateCompanionBuilder,
    (
      MonitoreosLocalData,
      BaseReferences<_$AppDatabase, $MonitoreosLocalTable, MonitoreosLocalData>
    ),
    MonitoreosLocalData,
    PrefetchHooks Function()> {
  $$MonitoreosLocalTableTableManager(
      _$AppDatabase db, $MonitoreosLocalTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MonitoreosLocalTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MonitoreosLocalTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MonitoreosLocalTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> pmmoSecuencia = const Value.absent(),
            Value<String?> pmltCodigo = const Value.absent(),
            Value<String?> pmmoCasa = const Value.absent(),
            Value<String?> pmmoCantero = const Value.absent(),
            Value<String?> pmmoCanteros = const Value.absent(),
            Value<String?> pmmoVariedad = const Value.absent(),
            Value<String?> pmmoGrower = const Value.absent(),
            Value<String?> pmniNombrecomun = const Value.absent(),
            Value<int?> pmmoCantidad = const Value.absent(),
            Value<int?> pmmoCantBotada = const Value.absent(),
            Value<String?> pmmoComentarios = const Value.absent(),
            Value<DateTime?> pmmoFecha = const Value.absent(),
            Value<bool> pmmoAutomatico = const Value.absent(),
            Value<int> pmmoEstatus = const Value.absent(),
            Value<int?> pmmoCreadopor = const Value.absent(),
            Value<String?> pmmoContenedor = const Value.absent(),
            Value<String?> pmmoIdvariedad = const Value.absent(),
            Value<int?> pmniId = const Value.absent(),
            Value<int?> pmmoMuestra1 = const Value.absent(),
            Value<int?> pmmoMuestra2 = const Value.absent(),
            Value<int?> pmmoMuestra3 = const Value.absent(),
            Value<int?> pmmoNivmuestraa1 = const Value.absent(),
            Value<int?> pmmoNivmuestraa2 = const Value.absent(),
            Value<int?> pmmoNivmuestraa3 = const Value.absent(),
            Value<int?> pmmoNivmuestram1 = const Value.absent(),
            Value<int?> pmmoNivmuestram2 = const Value.absent(),
            Value<int?> pmmoNivmuestram3 = const Value.absent(),
            Value<int?> lmsupniv1 = const Value.absent(),
            Value<int?> lmsupniv2 = const Value.absent(),
            Value<int?> lmsupniv3 = const Value.absent(),
            Value<bool> isLocal = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<int> version = const Value.absent(),
          }) =>
              MonitoreosLocalCompanion(
            pmmoSecuencia: pmmoSecuencia,
            pmltCodigo: pmltCodigo,
            pmmoCasa: pmmoCasa,
            pmmoCantero: pmmoCantero,
            pmmoCanteros: pmmoCanteros,
            pmmoVariedad: pmmoVariedad,
            pmmoGrower: pmmoGrower,
            pmniNombrecomun: pmniNombrecomun,
            pmmoCantidad: pmmoCantidad,
            pmmoCantBotada: pmmoCantBotada,
            pmmoComentarios: pmmoComentarios,
            pmmoFecha: pmmoFecha,
            pmmoAutomatico: pmmoAutomatico,
            pmmoEstatus: pmmoEstatus,
            pmmoCreadopor: pmmoCreadopor,
            pmmoContenedor: pmmoContenedor,
            pmmoIdvariedad: pmmoIdvariedad,
            pmniId: pmniId,
            pmmoMuestra1: pmmoMuestra1,
            pmmoMuestra2: pmmoMuestra2,
            pmmoMuestra3: pmmoMuestra3,
            pmmoNivmuestraa1: pmmoNivmuestraa1,
            pmmoNivmuestraa2: pmmoNivmuestraa2,
            pmmoNivmuestraa3: pmmoNivmuestraa3,
            pmmoNivmuestram1: pmmoNivmuestram1,
            pmmoNivmuestram2: pmmoNivmuestram2,
            pmmoNivmuestram3: pmmoNivmuestram3,
            lmsupniv1: lmsupniv1,
            lmsupniv2: lmsupniv2,
            lmsupniv3: lmsupniv3,
            isLocal: isLocal,
            syncedAt: syncedAt,
            version: version,
          ),
          createCompanionCallback: ({
            Value<int> pmmoSecuencia = const Value.absent(),
            Value<String?> pmltCodigo = const Value.absent(),
            Value<String?> pmmoCasa = const Value.absent(),
            Value<String?> pmmoCantero = const Value.absent(),
            Value<String?> pmmoCanteros = const Value.absent(),
            Value<String?> pmmoVariedad = const Value.absent(),
            Value<String?> pmmoGrower = const Value.absent(),
            Value<String?> pmniNombrecomun = const Value.absent(),
            Value<int?> pmmoCantidad = const Value.absent(),
            Value<int?> pmmoCantBotada = const Value.absent(),
            Value<String?> pmmoComentarios = const Value.absent(),
            Value<DateTime?> pmmoFecha = const Value.absent(),
            Value<bool> pmmoAutomatico = const Value.absent(),
            Value<int> pmmoEstatus = const Value.absent(),
            Value<int?> pmmoCreadopor = const Value.absent(),
            Value<String?> pmmoContenedor = const Value.absent(),
            Value<String?> pmmoIdvariedad = const Value.absent(),
            Value<int?> pmniId = const Value.absent(),
            Value<int?> pmmoMuestra1 = const Value.absent(),
            Value<int?> pmmoMuestra2 = const Value.absent(),
            Value<int?> pmmoMuestra3 = const Value.absent(),
            Value<int?> pmmoNivmuestraa1 = const Value.absent(),
            Value<int?> pmmoNivmuestraa2 = const Value.absent(),
            Value<int?> pmmoNivmuestraa3 = const Value.absent(),
            Value<int?> pmmoNivmuestram1 = const Value.absent(),
            Value<int?> pmmoNivmuestram2 = const Value.absent(),
            Value<int?> pmmoNivmuestram3 = const Value.absent(),
            Value<int?> lmsupniv1 = const Value.absent(),
            Value<int?> lmsupniv2 = const Value.absent(),
            Value<int?> lmsupniv3 = const Value.absent(),
            Value<bool> isLocal = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<int> version = const Value.absent(),
          }) =>
              MonitoreosLocalCompanion.insert(
            pmmoSecuencia: pmmoSecuencia,
            pmltCodigo: pmltCodigo,
            pmmoCasa: pmmoCasa,
            pmmoCantero: pmmoCantero,
            pmmoCanteros: pmmoCanteros,
            pmmoVariedad: pmmoVariedad,
            pmmoGrower: pmmoGrower,
            pmniNombrecomun: pmniNombrecomun,
            pmmoCantidad: pmmoCantidad,
            pmmoCantBotada: pmmoCantBotada,
            pmmoComentarios: pmmoComentarios,
            pmmoFecha: pmmoFecha,
            pmmoAutomatico: pmmoAutomatico,
            pmmoEstatus: pmmoEstatus,
            pmmoCreadopor: pmmoCreadopor,
            pmmoContenedor: pmmoContenedor,
            pmmoIdvariedad: pmmoIdvariedad,
            pmniId: pmniId,
            pmmoMuestra1: pmmoMuestra1,
            pmmoMuestra2: pmmoMuestra2,
            pmmoMuestra3: pmmoMuestra3,
            pmmoNivmuestraa1: pmmoNivmuestraa1,
            pmmoNivmuestraa2: pmmoNivmuestraa2,
            pmmoNivmuestraa3: pmmoNivmuestraa3,
            pmmoNivmuestram1: pmmoNivmuestram1,
            pmmoNivmuestram2: pmmoNivmuestram2,
            pmmoNivmuestram3: pmmoNivmuestram3,
            lmsupniv1: lmsupniv1,
            lmsupniv2: lmsupniv2,
            lmsupniv3: lmsupniv3,
            isLocal: isLocal,
            syncedAt: syncedAt,
            version: version,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MonitoreosLocalTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MonitoreosLocalTable,
    MonitoreosLocalData,
    $$MonitoreosLocalTableFilterComposer,
    $$MonitoreosLocalTableOrderingComposer,
    $$MonitoreosLocalTableAnnotationComposer,
    $$MonitoreosLocalTableCreateCompanionBuilder,
    $$MonitoreosLocalTableUpdateCompanionBuilder,
    (
      MonitoreosLocalData,
      BaseReferences<_$AppDatabase, $MonitoreosLocalTable, MonitoreosLocalData>
    ),
    MonitoreosLocalData,
    PrefetchHooks Function()>;
typedef $$CatalogosTableCreateCompanionBuilder = CatalogosCompanion Function({
  Value<int> id,
  required String tipo,
  Value<String?> clave,
  required String data,
  required DateTime updatedAt,
});
typedef $$CatalogosTableUpdateCompanionBuilder = CatalogosCompanion Function({
  Value<int> id,
  Value<String> tipo,
  Value<String?> clave,
  Value<String> data,
  Value<DateTime> updatedAt,
});

class $$CatalogosTableFilterComposer
    extends Composer<_$AppDatabase, $CatalogosTable> {
  $$CatalogosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tipo => $composableBuilder(
      column: $table.tipo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clave => $composableBuilder(
      column: $table.clave, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$CatalogosTableOrderingComposer
    extends Composer<_$AppDatabase, $CatalogosTable> {
  $$CatalogosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tipo => $composableBuilder(
      column: $table.tipo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clave => $composableBuilder(
      column: $table.clave, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$CatalogosTableAnnotationComposer
    extends Composer<_$AppDatabase, $CatalogosTable> {
  $$CatalogosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tipo =>
      $composableBuilder(column: $table.tipo, builder: (column) => column);

  GeneratedColumn<String> get clave =>
      $composableBuilder(column: $table.clave, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CatalogosTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CatalogosTable,
    Catalogo,
    $$CatalogosTableFilterComposer,
    $$CatalogosTableOrderingComposer,
    $$CatalogosTableAnnotationComposer,
    $$CatalogosTableCreateCompanionBuilder,
    $$CatalogosTableUpdateCompanionBuilder,
    (Catalogo, BaseReferences<_$AppDatabase, $CatalogosTable, Catalogo>),
    Catalogo,
    PrefetchHooks Function()> {
  $$CatalogosTableTableManager(_$AppDatabase db, $CatalogosTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatalogosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> tipo = const Value.absent(),
            Value<String?> clave = const Value.absent(),
            Value<String> data = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              CatalogosCompanion(
            id: id,
            tipo: tipo,
            clave: clave,
            data: data,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String tipo,
            Value<String?> clave = const Value.absent(),
            required String data,
            required DateTime updatedAt,
          }) =>
              CatalogosCompanion.insert(
            id: id,
            tipo: tipo,
            clave: clave,
            data: data,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CatalogosTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CatalogosTable,
    Catalogo,
    $$CatalogosTableFilterComposer,
    $$CatalogosTableOrderingComposer,
    $$CatalogosTableAnnotationComposer,
    $$CatalogosTableCreateCompanionBuilder,
    $$CatalogosTableUpdateCompanionBuilder,
    (Catalogo, BaseReferences<_$AppDatabase, $CatalogosTable, Catalogo>),
    Catalogo,
    PrefetchHooks Function()>;
typedef $$SyncMetadataTableCreateCompanionBuilder = SyncMetadataCompanion
    Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SyncMetadataTableUpdateCompanionBuilder = SyncMetadataCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SyncMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$SyncMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$SyncMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncMetadataTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncMetadataTable,
    SyncMetadataData,
    $$SyncMetadataTableFilterComposer,
    $$SyncMetadataTableOrderingComposer,
    $$SyncMetadataTableAnnotationComposer,
    $$SyncMetadataTableCreateCompanionBuilder,
    $$SyncMetadataTableUpdateCompanionBuilder,
    (
      SyncMetadataData,
      BaseReferences<_$AppDatabase, $SyncMetadataTable, SyncMetadataData>
    ),
    SyncMetadataData,
    PrefetchHooks Function()> {
  $$SyncMetadataTableTableManager(_$AppDatabase db, $SyncMetadataTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncMetadataCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncMetadataCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncMetadataTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncMetadataTable,
    SyncMetadataData,
    $$SyncMetadataTableFilterComposer,
    $$SyncMetadataTableOrderingComposer,
    $$SyncMetadataTableAnnotationComposer,
    $$SyncMetadataTableCreateCompanionBuilder,
    $$SyncMetadataTableUpdateCompanionBuilder,
    (
      SyncMetadataData,
      BaseReferences<_$AppDatabase, $SyncMetadataTable, SyncMetadataData>
    ),
    SyncMetadataData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$MonitoreosLocalTableTableManager get monitoreosLocal =>
      $$MonitoreosLocalTableTableManager(_db, _db.monitoreosLocal);
  $$CatalogosTableTableManager get catalogos =>
      $$CatalogosTableTableManager(_db, _db.catalogos);
  $$SyncMetadataTableTableManager get syncMetadata =>
      $$SyncMetadataTableTableManager(_db, _db.syncMetadata);
}
