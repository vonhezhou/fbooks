// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_database.dart';

// ignore_for_file: type=lint
class $StoredLibrarySourcesTable extends StoredLibrarySources
    with TableInfo<$StoredLibrarySourcesTable, StoredLibrarySource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredLibrarySourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endpointMeta = const VerificationMeta(
    'endpoint',
  );
  @override
  late final GeneratedColumn<String> endpoint = GeneratedColumn<String>(
    'endpoint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, kind, name, endpoint, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stored_library_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredLibrarySource> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('endpoint')) {
      context.handle(
        _endpointMeta,
        endpoint.isAcceptableOrUnknown(data['endpoint']!, _endpointMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredLibrarySource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredLibrarySource(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      endpoint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}endpoint'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $StoredLibrarySourcesTable createAlias(String alias) {
    return $StoredLibrarySourcesTable(attachedDatabase, alias);
  }
}

class StoredLibrarySource extends DataClass
    implements Insertable<StoredLibrarySource> {
  final String id;
  final String kind;
  final String name;
  final String? endpoint;
  final DateTime createdAt;
  const StoredLibrarySource({
    required this.id,
    required this.kind,
    required this.name,
    this.endpoint,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || endpoint != null) {
      map['endpoint'] = Variable<String>(endpoint);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  StoredLibrarySourcesCompanion toCompanion(bool nullToAbsent) {
    return StoredLibrarySourcesCompanion(
      id: Value(id),
      kind: Value(kind),
      name: Value(name),
      endpoint: endpoint == null && nullToAbsent
          ? const Value.absent()
          : Value(endpoint),
      createdAt: Value(createdAt),
    );
  }

  factory StoredLibrarySource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredLibrarySource(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
      endpoint: serializer.fromJson<String?>(json['endpoint']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String>(name),
      'endpoint': serializer.toJson<String?>(endpoint),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  StoredLibrarySource copyWith({
    String? id,
    String? kind,
    String? name,
    Value<String?> endpoint = const Value.absent(),
    DateTime? createdAt,
  }) => StoredLibrarySource(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    endpoint: endpoint.present ? endpoint.value : this.endpoint,
    createdAt: createdAt ?? this.createdAt,
  );
  StoredLibrarySource copyWithCompanion(StoredLibrarySourcesCompanion data) {
    return StoredLibrarySource(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      endpoint: data.endpoint.present ? data.endpoint.value : this.endpoint,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredLibrarySource(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('endpoint: $endpoint, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, name, endpoint, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredLibrarySource &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.endpoint == this.endpoint &&
          other.createdAt == this.createdAt);
}

class StoredLibrarySourcesCompanion
    extends UpdateCompanion<StoredLibrarySource> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> name;
  final Value<String?> endpoint;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const StoredLibrarySourcesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.endpoint = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredLibrarySourcesCompanion.insert({
    required String id,
    required String kind,
    required String name,
    this.endpoint = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<StoredLibrarySource> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<String>? endpoint,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (endpoint != null) 'endpoint': endpoint,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredLibrarySourcesCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? name,
    Value<String?>? endpoint,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return StoredLibrarySourcesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      endpoint: endpoint ?? this.endpoint,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (endpoint.present) {
      map['endpoint'] = Variable<String>(endpoint.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoredLibrarySourcesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('endpoint: $endpoint, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredPublicationsTable extends StoredPublications
    with TableInfo<$StoredPublicationsTable, StoredPublication> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredPublicationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorsJsonMeta = const VerificationMeta(
    'authorsJson',
  );
  @override
  late final GeneratedColumn<String> authorsJson = GeneratedColumn<String>(
    'authors_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverUriMeta = const VerificationMeta(
    'coverUri',
  );
  @override
  late final GeneratedColumn<String> coverUri = GeneratedColumn<String>(
    'cover_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    title,
    authorsJson,
    format,
    description,
    coverUri,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stored_publications';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredPublication> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('authors_json')) {
      context.handle(
        _authorsJsonMeta,
        authorsJson.isAcceptableOrUnknown(
          data['authors_json']!,
          _authorsJsonMeta,
        ),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('cover_uri')) {
      context.handle(
        _coverUriMeta,
        coverUri.isAcceptableOrUnknown(data['cover_uri']!, _coverUriMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredPublication map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredPublication(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      authorsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}authors_json'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      coverUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_uri'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $StoredPublicationsTable createAlias(String alias) {
    return $StoredPublicationsTable(attachedDatabase, alias);
  }
}

class StoredPublication extends DataClass
    implements Insertable<StoredPublication> {
  final String id;
  final String sourceId;
  final String title;
  final String authorsJson;
  final String format;
  final String? description;
  final String? coverUri;
  final DateTime createdAt;
  final DateTime updatedAt;
  const StoredPublication({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.authorsJson,
    required this.format,
    this.description,
    this.coverUri,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['title'] = Variable<String>(title);
    map['authors_json'] = Variable<String>(authorsJson);
    map['format'] = Variable<String>(format);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || coverUri != null) {
      map['cover_uri'] = Variable<String>(coverUri);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StoredPublicationsCompanion toCompanion(bool nullToAbsent) {
    return StoredPublicationsCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      title: Value(title),
      authorsJson: Value(authorsJson),
      format: Value(format),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      coverUri: coverUri == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUri),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredPublication.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredPublication(
      id: serializer.fromJson<String>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      title: serializer.fromJson<String>(json['title']),
      authorsJson: serializer.fromJson<String>(json['authorsJson']),
      format: serializer.fromJson<String>(json['format']),
      description: serializer.fromJson<String?>(json['description']),
      coverUri: serializer.fromJson<String?>(json['coverUri']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'title': serializer.toJson<String>(title),
      'authorsJson': serializer.toJson<String>(authorsJson),
      'format': serializer.toJson<String>(format),
      'description': serializer.toJson<String?>(description),
      'coverUri': serializer.toJson<String?>(coverUri),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredPublication copyWith({
    String? id,
    String? sourceId,
    String? title,
    String? authorsJson,
    String? format,
    Value<String?> description = const Value.absent(),
    Value<String?> coverUri = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StoredPublication(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    title: title ?? this.title,
    authorsJson: authorsJson ?? this.authorsJson,
    format: format ?? this.format,
    description: description.present ? description.value : this.description,
    coverUri: coverUri.present ? coverUri.value : this.coverUri,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredPublication copyWithCompanion(StoredPublicationsCompanion data) {
    return StoredPublication(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      title: data.title.present ? data.title.value : this.title,
      authorsJson: data.authorsJson.present
          ? data.authorsJson.value
          : this.authorsJson,
      format: data.format.present ? data.format.value : this.format,
      description: data.description.present
          ? data.description.value
          : this.description,
      coverUri: data.coverUri.present ? data.coverUri.value : this.coverUri,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredPublication(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('title: $title, ')
          ..write('authorsJson: $authorsJson, ')
          ..write('format: $format, ')
          ..write('description: $description, ')
          ..write('coverUri: $coverUri, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    title,
    authorsJson,
    format,
    description,
    coverUri,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredPublication &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.title == this.title &&
          other.authorsJson == this.authorsJson &&
          other.format == this.format &&
          other.description == this.description &&
          other.coverUri == this.coverUri &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class StoredPublicationsCompanion extends UpdateCompanion<StoredPublication> {
  final Value<String> id;
  final Value<String> sourceId;
  final Value<String> title;
  final Value<String> authorsJson;
  final Value<String> format;
  final Value<String?> description;
  final Value<String?> coverUri;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StoredPublicationsCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.title = const Value.absent(),
    this.authorsJson = const Value.absent(),
    this.format = const Value.absent(),
    this.description = const Value.absent(),
    this.coverUri = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredPublicationsCompanion.insert({
    required String id,
    required String sourceId,
    required String title,
    this.authorsJson = const Value.absent(),
    required String format,
    this.description = const Value.absent(),
    this.coverUri = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceId = Value(sourceId),
       title = Value(title),
       format = Value(format),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<StoredPublication> custom({
    Expression<String>? id,
    Expression<String>? sourceId,
    Expression<String>? title,
    Expression<String>? authorsJson,
    Expression<String>? format,
    Expression<String>? description,
    Expression<String>? coverUri,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (title != null) 'title': title,
      if (authorsJson != null) 'authors_json': authorsJson,
      if (format != null) 'format': format,
      if (description != null) 'description': description,
      if (coverUri != null) 'cover_uri': coverUri,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredPublicationsCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceId,
    Value<String>? title,
    Value<String>? authorsJson,
    Value<String>? format,
    Value<String?>? description,
    Value<String?>? coverUri,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StoredPublicationsCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      title: title ?? this.title,
      authorsJson: authorsJson ?? this.authorsJson,
      format: format ?? this.format,
      description: description ?? this.description,
      coverUri: coverUri ?? this.coverUri,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (authorsJson.present) {
      map['authors_json'] = Variable<String>(authorsJson.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (coverUri.present) {
      map['cover_uri'] = Variable<String>(coverUri.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoredPublicationsCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('title: $title, ')
          ..write('authorsJson: $authorsJson, ')
          ..write('format: $format, ')
          ..write('description: $description, ')
          ..write('coverUri: $coverUri, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredReadingProgressesTable extends StoredReadingProgresses
    with TableInfo<$StoredReadingProgressesTable, StoredReadingProgressesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredReadingProgressesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _publicationIdMeta = const VerificationMeta(
    'publicationId',
  );
  @override
  late final GeneratedColumn<String> publicationId = GeneratedColumn<String>(
    'publication_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locatorTypeMeta = const VerificationMeta(
    'locatorType',
  );
  @override
  late final GeneratedColumn<String> locatorType = GeneratedColumn<String>(
    'locator_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locatorValueMeta = const VerificationMeta(
    'locatorValue',
  );
  @override
  late final GeneratedColumn<String> locatorValue = GeneratedColumn<String>(
    'locator_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    publicationId,
    locatorType,
    locatorValue,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stored_reading_progresses';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredReadingProgressesData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('publication_id')) {
      context.handle(
        _publicationIdMeta,
        publicationId.isAcceptableOrUnknown(
          data['publication_id']!,
          _publicationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_publicationIdMeta);
    }
    if (data.containsKey('locator_type')) {
      context.handle(
        _locatorTypeMeta,
        locatorType.isAcceptableOrUnknown(
          data['locator_type']!,
          _locatorTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_locatorTypeMeta);
    }
    if (data.containsKey('locator_value')) {
      context.handle(
        _locatorValueMeta,
        locatorValue.isAcceptableOrUnknown(
          data['locator_value']!,
          _locatorValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_locatorValueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {publicationId};
  @override
  StoredReadingProgressesData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredReadingProgressesData(
      publicationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}publication_id'],
      )!,
      locatorType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locator_type'],
      )!,
      locatorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locator_value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $StoredReadingProgressesTable createAlias(String alias) {
    return $StoredReadingProgressesTable(attachedDatabase, alias);
  }
}

class StoredReadingProgressesData extends DataClass
    implements Insertable<StoredReadingProgressesData> {
  final String publicationId;
  final String locatorType;
  final String locatorValue;
  final DateTime updatedAt;
  const StoredReadingProgressesData({
    required this.publicationId,
    required this.locatorType,
    required this.locatorValue,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['publication_id'] = Variable<String>(publicationId);
    map['locator_type'] = Variable<String>(locatorType);
    map['locator_value'] = Variable<String>(locatorValue);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StoredReadingProgressesCompanion toCompanion(bool nullToAbsent) {
    return StoredReadingProgressesCompanion(
      publicationId: Value(publicationId),
      locatorType: Value(locatorType),
      locatorValue: Value(locatorValue),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredReadingProgressesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredReadingProgressesData(
      publicationId: serializer.fromJson<String>(json['publicationId']),
      locatorType: serializer.fromJson<String>(json['locatorType']),
      locatorValue: serializer.fromJson<String>(json['locatorValue']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'publicationId': serializer.toJson<String>(publicationId),
      'locatorType': serializer.toJson<String>(locatorType),
      'locatorValue': serializer.toJson<String>(locatorValue),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredReadingProgressesData copyWith({
    String? publicationId,
    String? locatorType,
    String? locatorValue,
    DateTime? updatedAt,
  }) => StoredReadingProgressesData(
    publicationId: publicationId ?? this.publicationId,
    locatorType: locatorType ?? this.locatorType,
    locatorValue: locatorValue ?? this.locatorValue,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredReadingProgressesData copyWithCompanion(
    StoredReadingProgressesCompanion data,
  ) {
    return StoredReadingProgressesData(
      publicationId: data.publicationId.present
          ? data.publicationId.value
          : this.publicationId,
      locatorType: data.locatorType.present
          ? data.locatorType.value
          : this.locatorType,
      locatorValue: data.locatorValue.present
          ? data.locatorValue.value
          : this.locatorValue,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredReadingProgressesData(')
          ..write('publicationId: $publicationId, ')
          ..write('locatorType: $locatorType, ')
          ..write('locatorValue: $locatorValue, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(publicationId, locatorType, locatorValue, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredReadingProgressesData &&
          other.publicationId == this.publicationId &&
          other.locatorType == this.locatorType &&
          other.locatorValue == this.locatorValue &&
          other.updatedAt == this.updatedAt);
}

class StoredReadingProgressesCompanion
    extends UpdateCompanion<StoredReadingProgressesData> {
  final Value<String> publicationId;
  final Value<String> locatorType;
  final Value<String> locatorValue;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StoredReadingProgressesCompanion({
    this.publicationId = const Value.absent(),
    this.locatorType = const Value.absent(),
    this.locatorValue = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredReadingProgressesCompanion.insert({
    required String publicationId,
    required String locatorType,
    required String locatorValue,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : publicationId = Value(publicationId),
       locatorType = Value(locatorType),
       locatorValue = Value(locatorValue),
       updatedAt = Value(updatedAt);
  static Insertable<StoredReadingProgressesData> custom({
    Expression<String>? publicationId,
    Expression<String>? locatorType,
    Expression<String>? locatorValue,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (publicationId != null) 'publication_id': publicationId,
      if (locatorType != null) 'locator_type': locatorType,
      if (locatorValue != null) 'locator_value': locatorValue,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredReadingProgressesCompanion copyWith({
    Value<String>? publicationId,
    Value<String>? locatorType,
    Value<String>? locatorValue,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StoredReadingProgressesCompanion(
      publicationId: publicationId ?? this.publicationId,
      locatorType: locatorType ?? this.locatorType,
      locatorValue: locatorValue ?? this.locatorValue,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (publicationId.present) {
      map['publication_id'] = Variable<String>(publicationId.value);
    }
    if (locatorType.present) {
      map['locator_type'] = Variable<String>(locatorType.value);
    }
    if (locatorValue.present) {
      map['locator_value'] = Variable<String>(locatorValue.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoredReadingProgressesCompanion(')
          ..write('publicationId: $publicationId, ')
          ..write('locatorType: $locatorType, ')
          ..write('locatorValue: $locatorValue, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredPublicationAssetsTable extends StoredPublicationAssets
    with TableInfo<$StoredPublicationAssetsTable, StoredPublicationAsset> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredPublicationAssetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _publicationIdMeta = const VerificationMeta(
    'publicationId',
  );
  @override
  late final GeneratedColumn<String> publicationId = GeneratedColumn<String>(
    'publication_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaTypeMeta = const VerificationMeta(
    'mediaType',
  );
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
    'media_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    publicationId,
    kind,
    location,
    mediaType,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stored_publication_assets';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredPublicationAsset> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('publication_id')) {
      context.handle(
        _publicationIdMeta,
        publicationId.isAcceptableOrUnknown(
          data['publication_id']!,
          _publicationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_publicationIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    } else if (isInserting) {
      context.missing(_locationMeta);
    }
    if (data.containsKey('media_type')) {
      context.handle(
        _mediaTypeMeta,
        mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredPublicationAsset map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredPublicationAsset(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      publicationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}publication_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      )!,
      mediaType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_type'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $StoredPublicationAssetsTable createAlias(String alias) {
    return $StoredPublicationAssetsTable(attachedDatabase, alias);
  }
}

class StoredPublicationAsset extends DataClass
    implements Insertable<StoredPublicationAsset> {
  final String id;
  final String publicationId;
  final String kind;
  final String location;
  final String? mediaType;
  final DateTime createdAt;
  const StoredPublicationAsset({
    required this.id,
    required this.publicationId,
    required this.kind,
    required this.location,
    this.mediaType,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['publication_id'] = Variable<String>(publicationId);
    map['kind'] = Variable<String>(kind);
    map['location'] = Variable<String>(location);
    if (!nullToAbsent || mediaType != null) {
      map['media_type'] = Variable<String>(mediaType);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  StoredPublicationAssetsCompanion toCompanion(bool nullToAbsent) {
    return StoredPublicationAssetsCompanion(
      id: Value(id),
      publicationId: Value(publicationId),
      kind: Value(kind),
      location: Value(location),
      mediaType: mediaType == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaType),
      createdAt: Value(createdAt),
    );
  }

  factory StoredPublicationAsset.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredPublicationAsset(
      id: serializer.fromJson<String>(json['id']),
      publicationId: serializer.fromJson<String>(json['publicationId']),
      kind: serializer.fromJson<String>(json['kind']),
      location: serializer.fromJson<String>(json['location']),
      mediaType: serializer.fromJson<String?>(json['mediaType']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'publicationId': serializer.toJson<String>(publicationId),
      'kind': serializer.toJson<String>(kind),
      'location': serializer.toJson<String>(location),
      'mediaType': serializer.toJson<String?>(mediaType),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  StoredPublicationAsset copyWith({
    String? id,
    String? publicationId,
    String? kind,
    String? location,
    Value<String?> mediaType = const Value.absent(),
    DateTime? createdAt,
  }) => StoredPublicationAsset(
    id: id ?? this.id,
    publicationId: publicationId ?? this.publicationId,
    kind: kind ?? this.kind,
    location: location ?? this.location,
    mediaType: mediaType.present ? mediaType.value : this.mediaType,
    createdAt: createdAt ?? this.createdAt,
  );
  StoredPublicationAsset copyWithCompanion(
    StoredPublicationAssetsCompanion data,
  ) {
    return StoredPublicationAsset(
      id: data.id.present ? data.id.value : this.id,
      publicationId: data.publicationId.present
          ? data.publicationId.value
          : this.publicationId,
      kind: data.kind.present ? data.kind.value : this.kind,
      location: data.location.present ? data.location.value : this.location,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredPublicationAsset(')
          ..write('id: $id, ')
          ..write('publicationId: $publicationId, ')
          ..write('kind: $kind, ')
          ..write('location: $location, ')
          ..write('mediaType: $mediaType, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, publicationId, kind, location, mediaType, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredPublicationAsset &&
          other.id == this.id &&
          other.publicationId == this.publicationId &&
          other.kind == this.kind &&
          other.location == this.location &&
          other.mediaType == this.mediaType &&
          other.createdAt == this.createdAt);
}

class StoredPublicationAssetsCompanion
    extends UpdateCompanion<StoredPublicationAsset> {
  final Value<String> id;
  final Value<String> publicationId;
  final Value<String> kind;
  final Value<String> location;
  final Value<String?> mediaType;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const StoredPublicationAssetsCompanion({
    this.id = const Value.absent(),
    this.publicationId = const Value.absent(),
    this.kind = const Value.absent(),
    this.location = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredPublicationAssetsCompanion.insert({
    required String id,
    required String publicationId,
    required String kind,
    required String location,
    this.mediaType = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       publicationId = Value(publicationId),
       kind = Value(kind),
       location = Value(location),
       createdAt = Value(createdAt);
  static Insertable<StoredPublicationAsset> custom({
    Expression<String>? id,
    Expression<String>? publicationId,
    Expression<String>? kind,
    Expression<String>? location,
    Expression<String>? mediaType,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (publicationId != null) 'publication_id': publicationId,
      if (kind != null) 'kind': kind,
      if (location != null) 'location': location,
      if (mediaType != null) 'media_type': mediaType,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredPublicationAssetsCompanion copyWith({
    Value<String>? id,
    Value<String>? publicationId,
    Value<String>? kind,
    Value<String>? location,
    Value<String?>? mediaType,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return StoredPublicationAssetsCompanion(
      id: id ?? this.id,
      publicationId: publicationId ?? this.publicationId,
      kind: kind ?? this.kind,
      location: location ?? this.location,
      mediaType: mediaType ?? this.mediaType,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (publicationId.present) {
      map['publication_id'] = Variable<String>(publicationId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoredPublicationAssetsCompanion(')
          ..write('id: $id, ')
          ..write('publicationId: $publicationId, ')
          ..write('kind: $kind, ')
          ..write('location: $location, ')
          ..write('mediaType: $mediaType, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDatabase extends GeneratedDatabase {
  _$LocalDatabase(QueryExecutor e) : super(e);
  $LocalDatabaseManager get managers => $LocalDatabaseManager(this);
  late final $StoredLibrarySourcesTable storedLibrarySources =
      $StoredLibrarySourcesTable(this);
  late final $StoredPublicationsTable storedPublications =
      $StoredPublicationsTable(this);
  late final $StoredReadingProgressesTable storedReadingProgresses =
      $StoredReadingProgressesTable(this);
  late final $StoredPublicationAssetsTable storedPublicationAssets =
      $StoredPublicationAssetsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    storedLibrarySources,
    storedPublications,
    storedReadingProgresses,
    storedPublicationAssets,
  ];
}

typedef $$StoredLibrarySourcesTableCreateCompanionBuilder =
    StoredLibrarySourcesCompanion Function({
      required String id,
      required String kind,
      required String name,
      Value<String?> endpoint,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$StoredLibrarySourcesTableUpdateCompanionBuilder =
    StoredLibrarySourcesCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> name,
      Value<String?> endpoint,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$StoredLibrarySourcesTableFilterComposer
    extends Composer<_$LocalDatabase, $StoredLibrarySourcesTable> {
  $$StoredLibrarySourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endpoint => $composableBuilder(
    column: $table.endpoint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredLibrarySourcesTableOrderingComposer
    extends Composer<_$LocalDatabase, $StoredLibrarySourcesTable> {
  $$StoredLibrarySourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endpoint => $composableBuilder(
    column: $table.endpoint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredLibrarySourcesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $StoredLibrarySourcesTable> {
  $$StoredLibrarySourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get endpoint =>
      $composableBuilder(column: $table.endpoint, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$StoredLibrarySourcesTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $StoredLibrarySourcesTable,
          StoredLibrarySource,
          $$StoredLibrarySourcesTableFilterComposer,
          $$StoredLibrarySourcesTableOrderingComposer,
          $$StoredLibrarySourcesTableAnnotationComposer,
          $$StoredLibrarySourcesTableCreateCompanionBuilder,
          $$StoredLibrarySourcesTableUpdateCompanionBuilder,
          (
            StoredLibrarySource,
            BaseReferences<
              _$LocalDatabase,
              $StoredLibrarySourcesTable,
              StoredLibrarySource
            >,
          ),
          StoredLibrarySource,
          PrefetchHooks Function()
        > {
  $$StoredLibrarySourcesTableTableManager(
    _$LocalDatabase db,
    $StoredLibrarySourcesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoredLibrarySourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StoredLibrarySourcesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$StoredLibrarySourcesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> endpoint = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredLibrarySourcesCompanion(
                id: id,
                kind: kind,
                name: name,
                endpoint: endpoint,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String name,
                Value<String?> endpoint = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => StoredLibrarySourcesCompanion.insert(
                id: id,
                kind: kind,
                name: name,
                endpoint: endpoint,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StoredLibrarySourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $StoredLibrarySourcesTable,
      StoredLibrarySource,
      $$StoredLibrarySourcesTableFilterComposer,
      $$StoredLibrarySourcesTableOrderingComposer,
      $$StoredLibrarySourcesTableAnnotationComposer,
      $$StoredLibrarySourcesTableCreateCompanionBuilder,
      $$StoredLibrarySourcesTableUpdateCompanionBuilder,
      (
        StoredLibrarySource,
        BaseReferences<
          _$LocalDatabase,
          $StoredLibrarySourcesTable,
          StoredLibrarySource
        >,
      ),
      StoredLibrarySource,
      PrefetchHooks Function()
    >;
typedef $$StoredPublicationsTableCreateCompanionBuilder =
    StoredPublicationsCompanion Function({
      required String id,
      required String sourceId,
      required String title,
      Value<String> authorsJson,
      required String format,
      Value<String?> description,
      Value<String?> coverUri,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$StoredPublicationsTableUpdateCompanionBuilder =
    StoredPublicationsCompanion Function({
      Value<String> id,
      Value<String> sourceId,
      Value<String> title,
      Value<String> authorsJson,
      Value<String> format,
      Value<String?> description,
      Value<String?> coverUri,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$StoredPublicationsTableFilterComposer
    extends Composer<_$LocalDatabase, $StoredPublicationsTable> {
  $$StoredPublicationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorsJson => $composableBuilder(
    column: $table.authorsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUri => $composableBuilder(
    column: $table.coverUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredPublicationsTableOrderingComposer
    extends Composer<_$LocalDatabase, $StoredPublicationsTable> {
  $$StoredPublicationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorsJson => $composableBuilder(
    column: $table.authorsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUri => $composableBuilder(
    column: $table.coverUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredPublicationsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $StoredPublicationsTable> {
  $$StoredPublicationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get authorsJson => $composableBuilder(
    column: $table.authorsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverUri =>
      $composableBuilder(column: $table.coverUri, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StoredPublicationsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $StoredPublicationsTable,
          StoredPublication,
          $$StoredPublicationsTableFilterComposer,
          $$StoredPublicationsTableOrderingComposer,
          $$StoredPublicationsTableAnnotationComposer,
          $$StoredPublicationsTableCreateCompanionBuilder,
          $$StoredPublicationsTableUpdateCompanionBuilder,
          (
            StoredPublication,
            BaseReferences<
              _$LocalDatabase,
              $StoredPublicationsTable,
              StoredPublication
            >,
          ),
          StoredPublication,
          PrefetchHooks Function()
        > {
  $$StoredPublicationsTableTableManager(
    _$LocalDatabase db,
    $StoredPublicationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoredPublicationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StoredPublicationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StoredPublicationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> authorsJson = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> coverUri = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredPublicationsCompanion(
                id: id,
                sourceId: sourceId,
                title: title,
                authorsJson: authorsJson,
                format: format,
                description: description,
                coverUri: coverUri,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceId,
                required String title,
                Value<String> authorsJson = const Value.absent(),
                required String format,
                Value<String?> description = const Value.absent(),
                Value<String?> coverUri = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => StoredPublicationsCompanion.insert(
                id: id,
                sourceId: sourceId,
                title: title,
                authorsJson: authorsJson,
                format: format,
                description: description,
                coverUri: coverUri,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StoredPublicationsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $StoredPublicationsTable,
      StoredPublication,
      $$StoredPublicationsTableFilterComposer,
      $$StoredPublicationsTableOrderingComposer,
      $$StoredPublicationsTableAnnotationComposer,
      $$StoredPublicationsTableCreateCompanionBuilder,
      $$StoredPublicationsTableUpdateCompanionBuilder,
      (
        StoredPublication,
        BaseReferences<
          _$LocalDatabase,
          $StoredPublicationsTable,
          StoredPublication
        >,
      ),
      StoredPublication,
      PrefetchHooks Function()
    >;
typedef $$StoredReadingProgressesTableCreateCompanionBuilder =
    StoredReadingProgressesCompanion Function({
      required String publicationId,
      required String locatorType,
      required String locatorValue,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$StoredReadingProgressesTableUpdateCompanionBuilder =
    StoredReadingProgressesCompanion Function({
      Value<String> publicationId,
      Value<String> locatorType,
      Value<String> locatorValue,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$StoredReadingProgressesTableFilterComposer
    extends Composer<_$LocalDatabase, $StoredReadingProgressesTable> {
  $$StoredReadingProgressesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get publicationId => $composableBuilder(
    column: $table.publicationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locatorType => $composableBuilder(
    column: $table.locatorType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locatorValue => $composableBuilder(
    column: $table.locatorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredReadingProgressesTableOrderingComposer
    extends Composer<_$LocalDatabase, $StoredReadingProgressesTable> {
  $$StoredReadingProgressesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get publicationId => $composableBuilder(
    column: $table.publicationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locatorType => $composableBuilder(
    column: $table.locatorType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locatorValue => $composableBuilder(
    column: $table.locatorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredReadingProgressesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $StoredReadingProgressesTable> {
  $$StoredReadingProgressesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get publicationId => $composableBuilder(
    column: $table.publicationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get locatorType => $composableBuilder(
    column: $table.locatorType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get locatorValue => $composableBuilder(
    column: $table.locatorValue,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StoredReadingProgressesTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $StoredReadingProgressesTable,
          StoredReadingProgressesData,
          $$StoredReadingProgressesTableFilterComposer,
          $$StoredReadingProgressesTableOrderingComposer,
          $$StoredReadingProgressesTableAnnotationComposer,
          $$StoredReadingProgressesTableCreateCompanionBuilder,
          $$StoredReadingProgressesTableUpdateCompanionBuilder,
          (
            StoredReadingProgressesData,
            BaseReferences<
              _$LocalDatabase,
              $StoredReadingProgressesTable,
              StoredReadingProgressesData
            >,
          ),
          StoredReadingProgressesData,
          PrefetchHooks Function()
        > {
  $$StoredReadingProgressesTableTableManager(
    _$LocalDatabase db,
    $StoredReadingProgressesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoredReadingProgressesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$StoredReadingProgressesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$StoredReadingProgressesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> publicationId = const Value.absent(),
                Value<String> locatorType = const Value.absent(),
                Value<String> locatorValue = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredReadingProgressesCompanion(
                publicationId: publicationId,
                locatorType: locatorType,
                locatorValue: locatorValue,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String publicationId,
                required String locatorType,
                required String locatorValue,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => StoredReadingProgressesCompanion.insert(
                publicationId: publicationId,
                locatorType: locatorType,
                locatorValue: locatorValue,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StoredReadingProgressesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $StoredReadingProgressesTable,
      StoredReadingProgressesData,
      $$StoredReadingProgressesTableFilterComposer,
      $$StoredReadingProgressesTableOrderingComposer,
      $$StoredReadingProgressesTableAnnotationComposer,
      $$StoredReadingProgressesTableCreateCompanionBuilder,
      $$StoredReadingProgressesTableUpdateCompanionBuilder,
      (
        StoredReadingProgressesData,
        BaseReferences<
          _$LocalDatabase,
          $StoredReadingProgressesTable,
          StoredReadingProgressesData
        >,
      ),
      StoredReadingProgressesData,
      PrefetchHooks Function()
    >;
typedef $$StoredPublicationAssetsTableCreateCompanionBuilder =
    StoredPublicationAssetsCompanion Function({
      required String id,
      required String publicationId,
      required String kind,
      required String location,
      Value<String?> mediaType,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$StoredPublicationAssetsTableUpdateCompanionBuilder =
    StoredPublicationAssetsCompanion Function({
      Value<String> id,
      Value<String> publicationId,
      Value<String> kind,
      Value<String> location,
      Value<String?> mediaType,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$StoredPublicationAssetsTableFilterComposer
    extends Composer<_$LocalDatabase, $StoredPublicationAssetsTable> {
  $$StoredPublicationAssetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publicationId => $composableBuilder(
    column: $table.publicationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredPublicationAssetsTableOrderingComposer
    extends Composer<_$LocalDatabase, $StoredPublicationAssetsTable> {
  $$StoredPublicationAssetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publicationId => $composableBuilder(
    column: $table.publicationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredPublicationAssetsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $StoredPublicationAssetsTable> {
  $$StoredPublicationAssetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get publicationId => $composableBuilder(
    column: $table.publicationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$StoredPublicationAssetsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $StoredPublicationAssetsTable,
          StoredPublicationAsset,
          $$StoredPublicationAssetsTableFilterComposer,
          $$StoredPublicationAssetsTableOrderingComposer,
          $$StoredPublicationAssetsTableAnnotationComposer,
          $$StoredPublicationAssetsTableCreateCompanionBuilder,
          $$StoredPublicationAssetsTableUpdateCompanionBuilder,
          (
            StoredPublicationAsset,
            BaseReferences<
              _$LocalDatabase,
              $StoredPublicationAssetsTable,
              StoredPublicationAsset
            >,
          ),
          StoredPublicationAsset,
          PrefetchHooks Function()
        > {
  $$StoredPublicationAssetsTableTableManager(
    _$LocalDatabase db,
    $StoredPublicationAssetsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoredPublicationAssetsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$StoredPublicationAssetsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$StoredPublicationAssetsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> publicationId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<String?> mediaType = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredPublicationAssetsCompanion(
                id: id,
                publicationId: publicationId,
                kind: kind,
                location: location,
                mediaType: mediaType,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String publicationId,
                required String kind,
                required String location,
                Value<String?> mediaType = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => StoredPublicationAssetsCompanion.insert(
                id: id,
                publicationId: publicationId,
                kind: kind,
                location: location,
                mediaType: mediaType,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StoredPublicationAssetsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $StoredPublicationAssetsTable,
      StoredPublicationAsset,
      $$StoredPublicationAssetsTableFilterComposer,
      $$StoredPublicationAssetsTableOrderingComposer,
      $$StoredPublicationAssetsTableAnnotationComposer,
      $$StoredPublicationAssetsTableCreateCompanionBuilder,
      $$StoredPublicationAssetsTableUpdateCompanionBuilder,
      (
        StoredPublicationAsset,
        BaseReferences<
          _$LocalDatabase,
          $StoredPublicationAssetsTable,
          StoredPublicationAsset
        >,
      ),
      StoredPublicationAsset,
      PrefetchHooks Function()
    >;

class $LocalDatabaseManager {
  final _$LocalDatabase _db;
  $LocalDatabaseManager(this._db);
  $$StoredLibrarySourcesTableTableManager get storedLibrarySources =>
      $$StoredLibrarySourcesTableTableManager(_db, _db.storedLibrarySources);
  $$StoredPublicationsTableTableManager get storedPublications =>
      $$StoredPublicationsTableTableManager(_db, _db.storedPublications);
  $$StoredReadingProgressesTableTableManager get storedReadingProgresses =>
      $$StoredReadingProgressesTableTableManager(
        _db,
        _db.storedReadingProgresses,
      );
  $$StoredPublicationAssetsTableTableManager get storedPublicationAssets =>
      $$StoredPublicationAssetsTableTableManager(
        _db,
        _db.storedPublicationAssets,
      );
}
