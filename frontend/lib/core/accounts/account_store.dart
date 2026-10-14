import 'dart:convert';

import '../models/app_failure.dart';
import '../models/label_draft.dart';
import '../models/product_report.dart';
import '../storage/local_store.dart';
import 'account_data.dart';

class AccountCache {
  AccountCache({
    required this.data,
    this.cloudRevision,
    this.dirty = false,
    this.localRevision = 0,
    this.pending,
  });
  final AccountData data;
  final int? cloudRevision;
  final bool dirty;
  final int localRevision;
  final AccountMutation? pending;
  JsonMap toJson() => {
    'schema_version': '1',
    'data': data.toJson(),
    'cloud_revision': cloudRevision,
    'dirty': dirty,
    'local_revision': localRevision,
    'pending': pending?.toJson(),
  };
  factory AccountCache.fromJson(JsonMap value) {
    final revision = value['cloud_revision'];
    final local = value['local_revision'];
    final pending = value['pending'];
    if (value['schema_version'] != '1' ||
        value['data'] is! JsonMap ||
        (revision != null &&
            (revision is! int || revision < 0 || revision > 2147483647)) ||
        value['dirty'] is! bool ||
        local is! int ||
        local < 0 ||
        (pending != null && pending is! JsonMap)) {
      throw const AppFailure(
        'local_data_corrupt',
        'This account library could not be read. Guest data is separate and still available.',
      );
    }
    return AccountCache(
      data: AccountData.fromJson(value['data'] as JsonMap),
      cloudRevision: revision as int?,
      dirty: value['dirty'] as bool,
      localRevision: local,
      pending: pending == null
          ? null
          : AccountMutation.fromJson(pending as JsonMap),
    );
  }
}

/// A separate account namespace selected only from the Firebase SDK's verified
/// session UID. Never wraps/relabels the guest namespace or imports it silently.
class AccountStore extends LocalStore {
  // Both the account cache and inherited device-only appearance need this adapter.
  // ignore: use_super_parameters
  AccountStore({
    required String uid,
    PreferencesAdapter? preferences,
    DateTime Function()? clock,
  }) : _preferences = preferences ?? AsyncPreferencesAdapter(),
       _clock = clock ?? DateTime.now,
       key = 'unlabel.account.v1.${base64Url.encode(utf8.encode(uid))}',
       super(preferences: preferences, clock: clock);
  final PreferencesAdapter _preferences;
  final DateTime Function() _clock;
  final String key;
  void Function()? onChanged;
  Future<void> _tail = Future.value();
  bool _deleted = false;
  bool _deletionPending = false;

  /// An admitted cloud deletion may finish even if its response is lost. Keep
  /// this retained namespace readable, but prevent any replacement or upload.
  void markDeletionPending() => _deletionPending = true;

  void _requireWritable() {
    if (_deletionPending) {
      throw const AppFailure(
        'account_delete_incomplete',
        'Account deletion is unfinished. Retry deleting the account before changing its private library.',
      );
    }
  }

  Future<T> _serial<T>(Future<T> Function() operation) {
    final next = _tail.then((_) {
      if (_deleted) {
        throw const AppFailure(
          'account_deleted',
          'This account was deleted. Its device library is no longer available.',
        );
      }
      return operation();
    });
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  /// Removes only this verified UID's namespace after confirmed Auth deletion.
  /// Serial admission stops an old retained store from recreating that cache.
  Future<void> deleteNamespace() => _serial(() async {
    _deleted = true;
    try {
      await _preferences.remove(key);
    } catch (_) {
      throw const AppFailure(
        'account_local_cleanup',
        'Your account was deleted, but this device could not clear its cached account library. Clear the app or site storage to remove that copy.',
      );
    }
  });

  Future<AccountCache> _read() async {
    try {
      final text = await _preferences.read(key);
      if (text == null) return AccountCache(data: AccountData());
      if (utf8.encode(text).length > LocalStore.maxNamespaceBytes) {
        throw const FormatException();
      }
      final raw = jsonDecode(text);
      if (raw is! JsonMap) throw const FormatException();
      return AccountCache.fromJson(raw);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'local_data_corrupt',
        'This account library could not be read. Guest data is separate and still available.',
      );
    }
  }

  Future<void> _write(AccountCache cache) async {
    _requireWritable();
    final text = jsonEncode(cache.toJson());
    if (utf8.encode(text).length > LocalStore.maxNamespaceBytes) {
      throw const AppFailure(
        'local_capacity',
        'This account library is full. Remove some reports before adding another.',
      );
    }
    try {
      await _preferences.write(key, text);
    } catch (_) {
      throw const AppFailure(
        'local_storage',
        'Account data could not be saved on this device. Please try again.',
      );
    }
  }

  Future<AccountCache> snapshot() => _serial(_read);
  Future<void> _edit(AccountData Function(AccountData) change) =>
      _serial(() async {
        final old = await _read();
        final next = change(old.data);
        if (next.sameContent(old.data)) return;
        await _write(
          AccountCache(
            data: next,
            cloudRevision: old.cloudRevision,
            dirty: true,
            localRevision: old.localRevision + 1,
            pending: old.pending,
          ),
        );
        onChanged?.call();
      });
  @override
  Future<List<LocalReport>> history() => _serial(
    () async => (await _read()).data.history.map((e) => e.toLocal()).toList(),
  );
  @override
  Future<List<LocalReport>> saved() => _serial(
    () async => (await _read()).data.saved.map((e) => e.toLocal()).toList(),
  );
  @override
  Future<void> record(ProductReport report) => _edit(
    (data) => data.copyWith(
      history: _add(data.history, report, LocalStore.maxHistory),
    ),
  );
  @override
  Future<void> save(ProductReport report) => _edit(
    (data) =>
        data.copyWith(saved: _add(data.saved, report, LocalStore.maxSaved)),
  );
  List<AccountEntry> _add(
    List<AccountEntry> entries,
    ProductReport report,
    int cap,
  ) {
    if (utf8.encode(jsonEncode(report.raw)).length >
        LocalStore.maxReportBytes) {
      throw const AppFailure(
        'local_capacity',
        'This report is too large to save.',
      );
    }
    final previous = entries.where((e) => e.report.id == report.id).firstOrNull;
    final next = entries.where((e) => e.report.id != report.id).toList();
    // Account libraries never silently trim data to meet cloud or count limits.
    if (next.length >= cap) {
      throw AppFailure(
        'local_capacity',
        'This account list is full ($cap reports). Remove reports before adding another.',
      );
    }
    return [
      AccountEntry(
        entryId: previous?.entryId ?? newSubmissionId(),
        recordedAt: _clock(),
        report: report,
      ),
      ...next,
    ];
  }

  @override
  Future<void> removeSaved(String id) => _edit(
    (data) => data.copyWith(
      saved: data.saved.where((e) => e.report.id != id).toList(),
    ),
  );
  @override
  Future<void> clearHistory() => _edit((data) => data.copyWith(history: []));
  @override
  Future<void> clearSaved() => _edit((data) => data.copyWith(saved: []));
  Future<void> setDisplayName(String? input) {
    final name = input?.trim();
    if (name != null &&
        (name.runes.length > 80 || RegExp(r'[\x00-\x1f\x7f]').hasMatch(name))) {
      throw const AppFailure(
        'invalid_input',
        'Use a display name up to 80 characters without line breaks.',
      );
    }
    return _edit(
      (data) => data.copyWith(
        displayName: name,
        clearName: name == null || name.isEmpty,
      ),
    );
  }

  Future<void> replaceLocal(AccountData data) => _edit((_) => data);
  Future<void> copyIntoEmpty(
    AccountData data, {
    required int expectedLocalRevision,
  }) => _serial(() async {
    final old = await _read();
    if (old.localRevision != expectedLocalRevision || !old.data.isEmpty) {
      throw const AppFailure(
        'sync_changed',
        'The account library changed. Check it again before copying guest reports.',
      );
    }
    if (old.data.sameContent(data)) return;
    await _write(
      AccountCache(
        data: data,
        cloudRevision: old.cloudRevision,
        dirty: true,
        localRevision: old.localRevision + 1,
        pending: old.pending,
      ),
    );
    onChanged?.call();
  });
  Future<AccountMutation> prepareMutation() => _serial(() async {
    final cache = await _read();
    if (cache.pending != null) return cache.pending!;
    cache.data.checkSyncSize();
    if (cache.cloudRevision == null) {
      throw const AppFailure(
        'sync_choice',
        'Check cloud data before uploading this device library.',
      );
    }
    final mutation = AccountMutation(
      expectedRevision: cache.cloudRevision!,
      data: cache.data,
    );
    await _write(
      AccountCache(
        data: cache.data,
        cloudRevision: cache.cloudRevision,
        dirty: cache.dirty,
        localRevision: cache.localRevision,
        pending: mutation,
      ),
    );
    return mutation;
  });
  Future<void> acceptUpload(AccountSnapshot cloud, String mutationId) =>
      _serial(() async {
        final cache = await _read();
        if (cache.pending?.id != mutationId) {
          throw const AppFailure(
            'sync_changed',
            'Pending sync changed. Please check sync again.',
          );
        }
        await _write(
          AccountCache(
            data: cache.data,
            cloudRevision: cloud.revision,
            dirty: !cache.data.sameContent(cloud.data),
            localRevision: cache.localRevision,
          ),
        );
      });
  Future<void> acceptCloud(
    AccountSnapshot cloud, {
    required int expectedLocalRevision,
  }) => _serial(() async {
    final cache = await _read();
    if (cache.localRevision != expectedLocalRevision) {
      throw const AppFailure(
        'sync_changed',
        'Your device library changed while checking sync. Check it again before replacing data.',
      );
    }
    await _write(
      AccountCache(
        data: cloud.data,
        cloudRevision: cloud.revision,
        localRevision: cache.localRevision + 1,
      ),
    );
  });
  Future<void> keepLocalAt(
    int cloudRevision, {
    required int expectedLocalRevision,
  }) => _serial(() async {
    final cache = await _read();
    if (cache.localRevision != expectedLocalRevision) {
      throw const AppFailure(
        'sync_changed',
        'Your device library changed. Check sync again before replacing cloud data.',
      );
    }
    await _write(
      AccountCache(
        data: cache.data,
        cloudRevision: cloudRevision,
        dirty: true,
        localRevision: cache.localRevision,
      ),
    );
  });
  Future<void> discardPending(String mutationId) => _serial(() async {
    final cache = await _read();
    if (cache.pending?.id != mutationId) return;
    await _write(
      AccountCache(
        data: cache.data,
        cloudRevision: cache.cloudRevision,
        dirty: cache.dirty,
        localRevision: cache.localRevision,
      ),
    );
  });
}
