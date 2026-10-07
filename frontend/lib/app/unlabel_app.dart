import 'dart:async';

import 'package:flutter/material.dart';

import '../core/network/scanner_auth.dart';
import '../core/network/unlabel_repository.dart';
import '../core/storage/local_store.dart';
import '../features/scanner/presentation/home_page.dart';
import '../features/scanner/presentation/label_entry_page.dart';
import '../features/scanner/presentation/library_page.dart';
import '../features/scanner/presentation/lookup_page.dart';
import '../features/scanner/presentation/report_page.dart';
import '../features/scanner/presentation/ui_components.dart';
import 'build_info.dart';
import 'firebase_options.dart';
import 'unlabel_theme.dart';
import 'web_appearance.dart';

class UnlabelApp extends StatefulWidget {
  const UnlabelApp({this.repository, this.store, super.key});

  final UnlabelRepository? repository;
  final LocalStore? store;

  @override
  State<UnlabelApp> createState() => _UnlabelAppState();
}

class _UnlabelAppState extends State<UnlabelApp> {
  ThemeMode _themeMode = ThemeMode.light;
  int _appearanceRevision = 0;
  late final UnlabelRepository _repository;
  late final LocalStore _store;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? LocalStore();
    _repository =
        widget.repository ??
        UnlabelRepository(
          baseUrl: BuildInfo.backendBaseUrl,
          auth: _scannerAuth(),
        );
    unawaited(_restoreAppearance());
  }

  Future<void> _restoreAppearance() async {
    final revision = _appearanceRevision;
    try {
      final saved = await _store.appearance();
      if (!mounted || revision != _appearanceRevision) return;
      setState(() => _themeMode = ThemeMode.values.byName(saved));
      setWebAppearance(saved);
    } on AppFailure {
      // Keep the usable light default; choosing an appearance repairs this key.
    }
  }

  Future<void> _setAppearance(ThemeMode mode) async {
    _appearanceRevision++;
    try {
      await _store.setAppearance(mode.name);
      if (!mounted) return;
      setState(() => _themeMode = mode);
      setWebAppearance(mode.name);
    } on AppFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(_homeContext!)
          .showSnackBar(SnackBar(content: Text(error.userMessage)));
    }
  }

  BuildContext? _homeContext;

  ScannerAuth _scannerAuth() {
    try {
      return FirebaseScannerAuth(
        options: UnlabelFirebaseOptions.currentPlatform,
      );
    } on UnsupportedError {
      return const UnavailableScannerAuth();
    }
  }

  @override
  void dispose() {
    if (widget.repository == null) _repository.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unlabel',
      debugShowCheckedModeBanner: false,
      theme: UnlabelTheme.forBrightness(Brightness.light),
      darkTheme: UnlabelTheme.forBrightness(Brightness.dark),
      themeMode: _themeMode,
      home: Builder(
        builder: (context) {
          _homeContext = context;
          return _ClientHome(
            repository: _repository,
            store: _store,
            themeMode: _themeMode,
            onThemeModeChanged: (value) => unawaited(_setAppearance(value)),
          );
        },
      ),
    );
  }
}

class _ClientHome extends StatefulWidget {
  const _ClientHome({
    required this.repository,
    required this.store,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final UnlabelRepository repository;
  final LocalStore store;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<_ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<_ClientHome> {
  int _tab = 0;
  int _refreshKey = 0;

  void _changed() {
    if (mounted) setState(() => _refreshKey++);
  }

  Future<void> _record(ProductReport report) async {
    try {
      await widget.store.record(report);
      _changed();
    } on AppFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.userMessage)));
      }
    }
  }

  Future<void> _openReport(ProductReport report, {bool record = false}) async {
    if (record) unawaited(_record(report));
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReportPage(
          report: report,
          store: widget.store,
          onChanged: _changed,
        ),
      ),
    );
  }

  void _lookup(bool barcode) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LookupPage(
          repository: widget.repository,
          barcodeMode: barcode,
          onOpenReport: (report) => _openReport(report, record: true),
          onEnterLabel: _enterLabel,
        ),
      ),
    );
  }

  void _enterLabel() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LabelEntryPage(
          repository: widget.repository,
          onReport: (report) => _openReport(report, record: true),
        ),
      ),
    );
  }

  void _about() {
    showAboutDialog(
      context: context,
      applicationName: 'Unlabel',
      applicationVersion: '${BuildInfo.version} (${BuildInfo.buildNumber})',
      applicationIcon: const FeatureIcon('leaf', size: 42),
      children: [
        const Text('Know Beyond the Label'),
        const SizedBox(height: 16),
        const Text(
          'Solar icons by 480 Design — CC BY 4.0. Icons are bundled locally; their license and source are included with the app.',
        ),
        const SizedBox(height: 12),
        const SelectableText('https://creativecommons.org/licenses/by/4.0/'),
        const SizedBox(height: 12),
        const Text(
          'Saved products and viewed reports stay on this device. Confirmed structured package facts are stored automatically when the service is available.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: largeText ? 118 : 90,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Unlabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (!largeText) const FeatureIcon('leaf', size: 22),
              ],
            ),
            Text(
              'Know Beyond the Label',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          PopupMenuButton<ThemeMode>(
            key: const Key('theme-selector'),
            tooltip: 'Appearance',
            icon: Icon(switch (widget.themeMode) {
              ThemeMode.light => Icons.light_mode_outlined,
              ThemeMode.dark => Icons.dark_mode_outlined,
              ThemeMode.system => Icons.brightness_auto_outlined,
            }),
            initialValue: widget.themeMode,
            onSelected: widget.onThemeModeChanged,
            itemBuilder: (_) => const [
              PopupMenuItem(value: ThemeMode.system, child: Text('System')),
              PopupMenuItem(value: ThemeMode.light, child: Text('Light')),
              PopupMenuItem(value: ThemeMode.dark, child: Text('Dark')),
            ],
          ),
          IconButton(
            onPressed: _about,
            tooltip: 'About Unlabel',
            icon: const Icon(Icons.info_outline),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _tab == 0
          ? HomePage(
              store: widget.store,
              refreshKey: _refreshKey,
              onLookup: _lookup,
              onEnterLabel: _enterLabel,
              onOpenReport: _openReport,
              onLibrary: (tab) => setState(() => _tab = tab),
            )
          : LibraryPage(
              saved: _tab == 1,
              store: widget.store,
              refreshKey: _refreshKey,
              onOpenReport: _openReport,
              onLookup: () => _lookup(true),
              onChanged: _changed,
            ),
      bottomNavigationBar: NavigationBar(
        height: largeText ? 108 : 82,
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(icon: FeatureIcon('bookmark'), label: 'Saved'),
          NavigationDestination(icon: FeatureIcon('history'), label: 'History'),
        ],
      ),
    );
  }
}
