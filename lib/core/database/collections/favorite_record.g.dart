// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetFavoriteRecordCollection on Isar {
  IsarCollection<FavoriteRecord> get favoriteRecords => this.collection();
}

const FavoriteRecordSchema = CollectionSchema(
  name: r'FavoriteRecord',
  id: -8548526311285793424,
  properties: {
    r'originalText': PropertySchema(
      id: 0,
      name: r'originalText',
      type: IsarType.string,
    ),
    r'recordId': PropertySchema(
      id: 1,
      name: r'recordId',
      type: IsarType.string,
    ),
    r'sourceLang': PropertySchema(
      id: 2,
      name: r'sourceLang',
      type: IsarType.string,
    ),
    r'targetLang': PropertySchema(
      id: 3,
      name: r'targetLang',
      type: IsarType.string,
    ),
    r'timestamp': PropertySchema(
      id: 4,
      name: r'timestamp',
      type: IsarType.dateTime,
    ),
    r'translatedText': PropertySchema(
      id: 5,
      name: r'translatedText',
      type: IsarType.string,
    ),
  },

  estimateSize: _favoriteRecordEstimateSize,
  serialize: _favoriteRecordSerialize,
  deserialize: _favoriteRecordDeserialize,
  deserializeProp: _favoriteRecordDeserializeProp,
  idName: r'id',
  indexes: {
    r'recordId': IndexSchema(
      id: 907839981883940929,
      name: r'recordId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'recordId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'timestamp': IndexSchema(
      id: 1852253767416892198,
      name: r'timestamp',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'timestamp',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _favoriteRecordGetId,
  getLinks: _favoriteRecordGetLinks,
  attach: _favoriteRecordAttach,
  version: '3.3.2',
);

int _favoriteRecordEstimateSize(
  FavoriteRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.originalText.length * 3;
  bytesCount += 3 + object.recordId.length * 3;
  bytesCount += 3 + object.sourceLang.length * 3;
  bytesCount += 3 + object.targetLang.length * 3;
  bytesCount += 3 + object.translatedText.length * 3;
  return bytesCount;
}

void _favoriteRecordSerialize(
  FavoriteRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.originalText);
  writer.writeString(offsets[1], object.recordId);
  writer.writeString(offsets[2], object.sourceLang);
  writer.writeString(offsets[3], object.targetLang);
  writer.writeDateTime(offsets[4], object.timestamp);
  writer.writeString(offsets[5], object.translatedText);
}

FavoriteRecord _favoriteRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = FavoriteRecord();
  object.id = id;
  object.originalText = reader.readString(offsets[0]);
  object.recordId = reader.readString(offsets[1]);
  object.sourceLang = reader.readString(offsets[2]);
  object.targetLang = reader.readString(offsets[3]);
  object.timestamp = reader.readDateTime(offsets[4]);
  object.translatedText = reader.readString(offsets[5]);
  return object;
}

P _favoriteRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readDateTime(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _favoriteRecordGetId(FavoriteRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _favoriteRecordGetLinks(FavoriteRecord object) {
  return [];
}

void _favoriteRecordAttach(
  IsarCollection<dynamic> col,
  Id id,
  FavoriteRecord object,
) {
  object.id = id;
}

extension FavoriteRecordByIndex on IsarCollection<FavoriteRecord> {
  Future<FavoriteRecord?> getByRecordId(String recordId) {
    return getByIndex(r'recordId', [recordId]);
  }

  FavoriteRecord? getByRecordIdSync(String recordId) {
    return getByIndexSync(r'recordId', [recordId]);
  }

  Future<bool> deleteByRecordId(String recordId) {
    return deleteByIndex(r'recordId', [recordId]);
  }

  bool deleteByRecordIdSync(String recordId) {
    return deleteByIndexSync(r'recordId', [recordId]);
  }

  Future<List<FavoriteRecord?>> getAllByRecordId(List<String> recordIdValues) {
    final values = recordIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'recordId', values);
  }

  List<FavoriteRecord?> getAllByRecordIdSync(List<String> recordIdValues) {
    final values = recordIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'recordId', values);
  }

  Future<int> deleteAllByRecordId(List<String> recordIdValues) {
    final values = recordIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'recordId', values);
  }

  int deleteAllByRecordIdSync(List<String> recordIdValues) {
    final values = recordIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'recordId', values);
  }

  Future<Id> putByRecordId(FavoriteRecord object) {
    return putByIndex(r'recordId', object);
  }

  Id putByRecordIdSync(FavoriteRecord object, {bool saveLinks = true}) {
    return putByIndexSync(r'recordId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByRecordId(List<FavoriteRecord> objects) {
    return putAllByIndex(r'recordId', objects);
  }

  List<Id> putAllByRecordIdSync(
    List<FavoriteRecord> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'recordId', objects, saveLinks: saveLinks);
  }
}

extension FavoriteRecordQueryWhereSort
    on QueryBuilder<FavoriteRecord, FavoriteRecord, QWhere> {
  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterWhere> anyTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'timestamp'),
      );
    });
  }
}

extension FavoriteRecordQueryWhere
    on QueryBuilder<FavoriteRecord, FavoriteRecord, QWhereClause> {
  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterWhereClause>
  recordIdEqualTo(String recordId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'recordId', value: [recordId]),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterWhereClause>
  recordIdNotEqualTo(String recordId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'recordId',
                lower: [],
                upper: [recordId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'recordId',
                lower: [recordId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'recordId',
                lower: [recordId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'recordId',
                lower: [],
                upper: [recordId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterWhereClause>
  timestampEqualTo(DateTime timestamp) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'timestamp', value: [timestamp]),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterWhereClause>
  timestampNotEqualTo(DateTime timestamp) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'timestamp',
                lower: [],
                upper: [timestamp],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'timestamp',
                lower: [timestamp],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'timestamp',
                lower: [timestamp],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'timestamp',
                lower: [],
                upper: [timestamp],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterWhereClause>
  timestampGreaterThan(DateTime timestamp, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'timestamp',
          lower: [timestamp],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterWhereClause>
  timestampLessThan(DateTime timestamp, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'timestamp',
          lower: [],
          upper: [timestamp],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterWhereClause>
  timestampBetween(
    DateTime lowerTimestamp,
    DateTime upperTimestamp, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'timestamp',
          lower: [lowerTimestamp],
          includeLower: includeLower,
          upper: [upperTimestamp],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension FavoriteRecordQueryFilter
    on QueryBuilder<FavoriteRecord, FavoriteRecord, QFilterCondition> {
  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  originalTextEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'originalText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  originalTextGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'originalText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  originalTextLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'originalText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  originalTextBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'originalText',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  originalTextStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'originalText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  originalTextEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'originalText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  originalTextContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'originalText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  originalTextMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'originalText',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  originalTextIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'originalText', value: ''),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  originalTextIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'originalText', value: ''),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  recordIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'recordId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  recordIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'recordId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  recordIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'recordId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  recordIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'recordId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  recordIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'recordId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  recordIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'recordId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  recordIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'recordId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  recordIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'recordId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  recordIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'recordId', value: ''),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  recordIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'recordId', value: ''),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  sourceLangEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'sourceLang',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  sourceLangGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sourceLang',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  sourceLangLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sourceLang',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  sourceLangBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sourceLang',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  sourceLangStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'sourceLang',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  sourceLangEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'sourceLang',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  sourceLangContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'sourceLang',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  sourceLangMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'sourceLang',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  sourceLangIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sourceLang', value: ''),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  sourceLangIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'sourceLang', value: ''),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  targetLangEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'targetLang',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  targetLangGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'targetLang',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  targetLangLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'targetLang',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  targetLangBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'targetLang',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  targetLangStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'targetLang',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  targetLangEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'targetLang',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  targetLangContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'targetLang',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  targetLangMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'targetLang',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  targetLangIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'targetLang', value: ''),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  targetLangIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'targetLang', value: ''),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  timestampEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'timestamp', value: value),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  timestampGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'timestamp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  timestampLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'timestamp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  timestampBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'timestamp',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  translatedTextEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'translatedText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  translatedTextGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'translatedText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  translatedTextLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'translatedText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  translatedTextBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'translatedText',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  translatedTextStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'translatedText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  translatedTextEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'translatedText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  translatedTextContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'translatedText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  translatedTextMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'translatedText',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  translatedTextIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'translatedText', value: ''),
      );
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterFilterCondition>
  translatedTextIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'translatedText', value: ''),
      );
    });
  }
}

extension FavoriteRecordQueryObject
    on QueryBuilder<FavoriteRecord, FavoriteRecord, QFilterCondition> {}

extension FavoriteRecordQueryLinks
    on QueryBuilder<FavoriteRecord, FavoriteRecord, QFilterCondition> {}

extension FavoriteRecordQuerySortBy
    on QueryBuilder<FavoriteRecord, FavoriteRecord, QSortBy> {
  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy>
  sortByOriginalText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalText', Sort.asc);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy>
  sortByOriginalTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalText', Sort.desc);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy> sortByRecordId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordId', Sort.asc);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy>
  sortByRecordIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordId', Sort.desc);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy>
  sortBySourceLang() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceLang', Sort.asc);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy>
  sortBySourceLangDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceLang', Sort.desc);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy>
  sortByTargetLang() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetLang', Sort.asc);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy>
  sortByTargetLangDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetLang', Sort.desc);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy> sortByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy>
  sortByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy>
  sortByTranslatedText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'translatedText', Sort.asc);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy>
  sortByTranslatedTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'translatedText', Sort.desc);
    });
  }
}

extension FavoriteRecordQuerySortThenBy
    on QueryBuilder<FavoriteRecord, FavoriteRecord, QSortThenBy> {
  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy>
  thenByOriginalText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalText', Sort.asc);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy>
  thenByOriginalTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalText', Sort.desc);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy> thenByRecordId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordId', Sort.asc);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy>
  thenByRecordIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordId', Sort.desc);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy>
  thenBySourceLang() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceLang', Sort.asc);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy>
  thenBySourceLangDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceLang', Sort.desc);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy>
  thenByTargetLang() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetLang', Sort.asc);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy>
  thenByTargetLangDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetLang', Sort.desc);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy> thenByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy>
  thenByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy>
  thenByTranslatedText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'translatedText', Sort.asc);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QAfterSortBy>
  thenByTranslatedTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'translatedText', Sort.desc);
    });
  }
}

extension FavoriteRecordQueryWhereDistinct
    on QueryBuilder<FavoriteRecord, FavoriteRecord, QDistinct> {
  QueryBuilder<FavoriteRecord, FavoriteRecord, QDistinct>
  distinctByOriginalText({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'originalText', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QDistinct> distinctByRecordId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'recordId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QDistinct> distinctBySourceLang({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceLang', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QDistinct> distinctByTargetLang({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'targetLang', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QDistinct>
  distinctByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestamp');
    });
  }

  QueryBuilder<FavoriteRecord, FavoriteRecord, QDistinct>
  distinctByTranslatedText({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'translatedText',
        caseSensitive: caseSensitive,
      );
    });
  }
}

extension FavoriteRecordQueryProperty
    on QueryBuilder<FavoriteRecord, FavoriteRecord, QQueryProperty> {
  QueryBuilder<FavoriteRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<FavoriteRecord, String, QQueryOperations>
  originalTextProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'originalText');
    });
  }

  QueryBuilder<FavoriteRecord, String, QQueryOperations> recordIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'recordId');
    });
  }

  QueryBuilder<FavoriteRecord, String, QQueryOperations> sourceLangProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceLang');
    });
  }

  QueryBuilder<FavoriteRecord, String, QQueryOperations> targetLangProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetLang');
    });
  }

  QueryBuilder<FavoriteRecord, DateTime, QQueryOperations> timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestamp');
    });
  }

  QueryBuilder<FavoriteRecord, String, QQueryOperations>
  translatedTextProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'translatedText');
    });
  }
}
