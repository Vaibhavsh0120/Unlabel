// Developer-only visual review entry point; production main.dart never imports it.
// Runs the real UnlabelApp shell, pages and controls with memory-only guest data.
// ?appearance=dark&scale=2 changes review conditions; ?saved=1 seeds two
// editorial bookmarks as an explicit developer fixture, never real user data.
// Navigate to Insights and Profile using the actual app's controls.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/testing.dart';
import 'package:unlabel/app/unlabel_app.dart';
import 'package:unlabel/core/accounts/account_auth.dart';
import 'package:unlabel/core/accounts/account_controller.dart';
import 'package:unlabel/core/accounts/account_data.dart';
import 'package:unlabel/core/accounts/account_sync_api.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/scanner/domain/insight_controller.dart';

class _MemoryPreferences implements PreferencesAdapter {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

class _DisabledSync implements AccountSyncTransport {
  @override
  Future<bool> available() async => false;

  @override
  Future<AccountSnapshot> fetch(String token) async => throw StateError(
    'The developer guest preview cannot fetch private data.',
  );

  @override
  Future<AccountSnapshot> put(String token, AccountMutation mutation) async =>
      throw StateError(
        'The developer guest preview cannot upload private data.',
      );

  @override
  void cancelAll() {}

  @override
  void close() {}
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final query = Uri.base.queryParameters;
  final preferences = _MemoryPreferences();
  preferences.values[LocalStore.appearanceKey] = query['appearance'] == 'dark'
      ? 'dark'
      : 'light';
  preferences.values[LocalStore.welcomeKey] = '1';
  if (query['saved'] == '1') {
    // Dedicated, memory-only editorial fixture; no product/account records.
    preferences.values[InsightController.savedKey] = jsonEncode({
      'schema_version': 1,
      'ids': ['added-sugar', 'snack-portions'],
    });
  }
  runApp(
    _PreviewApp(
      preferences: preferences,
      textScale: query['scale'] == '2' ? 2 : 1,
    ),
  );
}

class _PreviewApp extends StatefulWidget {
  const _PreviewApp({required this.preferences, required this.textScale});

  final _MemoryPreferences preferences;
  final double textScale;

  @override
  State<_PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<_PreviewApp> {
  late final _store = LocalStore(preferences: widget.preferences);
  late final _auth = UnavailableAccountAuth();
  late final _sync = _DisabledSync();
  late final _account = AccountController(
    auth: _auth,
    api: _sync,
    guestStore: _store,
    preferences: widget.preferences,
  );
  late final _repository = UnlabelRepository(
    baseUrl: 'http://127.0.0.1:1',
    allowLocalHttp: true,
    // No provider or network request can leave this developer fixture.
    client: MockClient(
      (_) async => throw const AppFailure(
        'preview_network_disabled',
        'Product lookup is unavailable in this developer preview.',
      ),
    ),
  );

  @override
  void dispose() {
    _account.dispose();
    _auth.dispose();
    _sync.close();
    _repository.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(widget.textScale)),
    child: UnlabelApp(
      store: _store,
      repository: _repository,
      accountController: _account,
      showWelcome: false,
    ),
  );
}
