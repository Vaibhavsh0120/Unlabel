import 'dart:convert';

import '../models/app_failure.dart';
import '../models/label_draft.dart';
import '../models/product_report.dart';
import '../storage/local_store.dart';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

class AccountEntry {
  const AccountEntry({
    required this.entryId,
    required this.recordedAt,
    required this.report,
  });
  final String entryId;
  final DateTime recordedAt;
  final ProductReport report;
  LocalReport toLocal() =>
      LocalReport(id: report.id, report: report, storedAt: recordedAt);
  JsonMap toJson() => {
    'entry_id': entryId,
    'recorded_at': recordedAt.toUtc().toIso8601String(),
    'report': report.raw,
  };
  factory AccountEntry.fromJson(JsonMap value) {
    final id = value['entry_id'];
    final at = value['recorded_at'];
    final raw = value['report'];
    if (value.keys.toSet().difference({
          'entry_id',
          'recorded_at',
          'report',
        }).isNotEmpty ||
        id is! String ||
        !_uuid.hasMatch(id) ||
        at is! String ||
        !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(at) ||
        DateTime.tryParse(at) == null ||
        raw is! JsonMap) {
      throw const AppFailure(
        'invalid_response',
        'A synced report could not be read. Your device data was kept.',
      );
    }
    return AccountEntry(
      entryId: id,
      recordedAt: DateTime.parse(at),
      report: ProductReport.fromJson(raw),
    );
  }
}

class AccountData {
  AccountData({
    this.displayName,
    List<AccountEntry> saved = const [],
    List<AccountEntry> history = const [],
  }) : saved = List.unmodifiable(saved),
       history = List.unmodifiable(history);
  static const maxSyncBytes = 384 * 1024;
  final String? displayName;
  final List<AccountEntry> saved;
  final List<AccountEntry> history;
  bool get isEmpty => displayName == null && saved.isEmpty && history.isEmpty;
  JsonMap toJson() => {
    'profile': {'display_name': displayName},
    'saved': saved.map((e) => e.toJson()).toList(),
    'history': history.map((e) => e.toJson()).toList(),
  };
  String get encoded => jsonEncode(toJson());

  /// A server may reorder JSON keys or serialize 4.0 as 4. Pending request
  /// bytes stay untouched for retries; acknowledgement compares their meaning.
  bool sameContent(AccountData other) => _sameJson(toJson(), other.toJson());
  void checkSyncSize() {
    if (utf8.encode(encoded).length > maxSyncBytes) {
      throw const AppFailure(
        'sync_capacity',
        'Your device library is larger than the free sync limit. Remove some account reports before syncing; no reports were silently dropped.',
      );
    }
  }

  factory AccountData.fromJson(JsonMap value) {
    final profile = value['profile'];
    final saved = value['saved'];
    final history = value['history'];
    if (value.keys.toSet().difference({
          'profile',
          'saved',
          'history',
        }).isNotEmpty ||
        profile is! JsonMap ||
        profile.keys.toSet().difference({'display_name'}).isNotEmpty ||
        saved is! List ||
        saved.length > 50 ||
        history is! List ||
        history.length > 100) {
      throw const AppFailure(
        'invalid_response',
        'Synced data could not be read. Your device data was kept.',
      );
    }
    final name = profile['display_name'];
    if (name != null &&
        (name is! String ||
            name.trim().isEmpty ||
            name.runes.length > 80 ||
            RegExp(r'[\x00-\x1f\x7f]').hasMatch(name))) {
      throw const AppFailure(
        'invalid_response',
        'The synced profile could not be read.',
      );
    }
    List<AccountEntry> entries(List values) {
      final result = values.map((v) {
        if (v is! JsonMap) {
          throw const AppFailure(
            'invalid_response',
            'A synced report could not be read.',
          );
        }
        return AccountEntry.fromJson(v);
      }).toList();
      if (result.map((e) => e.entryId).toSet().length != result.length) {
        throw const AppFailure(
          'invalid_response',
          'The synced library contains duplicate identifiers.',
        );
      }
      return result;
    }

    return AccountData(
      displayName: name as String?,
      saved: entries(saved),
      history: entries(history),
    );
  }
  AccountData copyWith({
    String? displayName,
    bool clearName = false,
    List<AccountEntry>? saved,
    List<AccountEntry>? history,
  }) => AccountData(
    displayName: clearName ? null : displayName ?? this.displayName,
    saved: saved ?? this.saved,
    history: history ?? this.history,
  );
}

bool _sameJson(Object? left, Object? right, [String? field]) {
  if (left is Map && right is Map) {
    return left.length == right.length &&
        left.keys.every(
          (key) =>
              right.containsKey(key) &&
              _sameJson(left[key], right[key], key as String),
        );
  }
  if (left is List && right is List) {
    return left.length == right.length &&
        List.generate(
          left.length,
          (index) => _sameJson(left[index], right[index]),
        ).every((same) => same);
  }
  if (left is String &&
      right is String &&
      const {
        'generated_at',
        'recorded_at',
        'observed_at',
        'updated_at',
        'retrieved_at',
        'assessed_at',
        'submitted_at',
        'reviewed_at',
        'expires_at',
        'source_updated_at',
        'exported_at',
        'indexed_at',
        'last_modified_at',
        'provider_modified_at',
        'normalized_at',
      }.contains(field)) {
    final aware = RegExp(r'(Z|[+-]\d{2}:\d{2})$');
    if (aware.hasMatch(left) && aware.hasMatch(right)) {
      final a = DateTime.tryParse(left);
      final b = DateTime.tryParse(right);
      if (a != null && b != null) return a.isAtSameMomentAs(b);
    }
  }
  return left == right;
}

class AccountSnapshot {
  const AccountSnapshot({
    required this.revision,
    required this.data,
    this.updatedAt,
  });
  final int revision;
  final AccountData data;
  final DateTime? updatedAt;
  factory AccountSnapshot.fromJson(JsonMap value) {
    final revision = value['revision'];
    final at = value['updated_at'];
    if (value['schema_version'] != '1' ||
        value['sync_version'] != 'personal-sync-v1' ||
        revision is! int ||
        revision < 0 ||
        revision > 2147483647 ||
        value['data'] is! JsonMap ||
        (revision == 0) != (at == null) ||
        (at != null &&
            (at is! String ||
                !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(at) ||
                DateTime.tryParse(at) == null))) {
      throw const AppFailure(
        'invalid_response',
        'The sync service returned data we could not read.',
      );
    }
    final data = AccountData.fromJson(value['data'] as JsonMap)
      ..checkSyncSize();
    return AccountSnapshot(
      revision: revision,
      data: data,
      updatedAt: at == null ? null : DateTime.parse(at as String),
    );
  }
}

class AccountMutation {
  AccountMutation({
    required this.expectedRevision,
    required this.data,
    String? id,
  }) : id = id ?? newSubmissionId();
  final int expectedRevision;
  final String id;
  final AccountData data;
  JsonMap toJson() => {
    'schema_version': '1',
    'expected_revision': expectedRevision,
    'mutation_id': id,
    'data': data.toJson(),
  };
  factory AccountMutation.fromJson(JsonMap value) {
    final id = value['mutation_id'];
    final revision = value['expected_revision'];
    if (value['schema_version'] != '1' ||
        id is! String ||
        !_uuid.hasMatch(id) ||
        revision is! int ||
        revision < 0 ||
        revision > 2147483647 ||
        value['data'] is! JsonMap) {
      throw const AppFailure(
        'local_data_corrupt',
        'A pending sync could not be read. Your local reports were kept.',
      );
    }
    return AccountMutation(
      expectedRevision: revision,
      id: id,
      data: AccountData.fromJson(value['data'] as JsonMap),
    );
  }
}
