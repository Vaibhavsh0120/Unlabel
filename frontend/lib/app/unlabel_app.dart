import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../core/accounts/account_auth.dart';
import '../core/accounts/account_controller.dart';
import '../core/accounts/account_sync_api.dart';
import '../core/accounts/profile_media.dart';
import '../core/interaction/ui_feedback.dart';
import '../core/network/scanner_auth.dart';
import '../core/network/unlabel_repository.dart';
import '../core/storage/local_store.dart';
import '../core/widgets/brand_mark.dart';
import 'artwork_warmup.dart';
import '../features/account/presentation/profile_page.dart';
import '../features/account/presentation/profile_avatar.dart';
import '../features/account/presentation/auth_page.dart';
import '../features/scanner/presentation/compare_page.dart';
import '../features/scanner/presentation/app_shell.dart';
import '../features/scanner/presentation/home_page.dart';
import '../features/scanner/presentation/desktop_navigation.dart';
import '../features/scanner/presentation/insights_page.dart';
import '../features/scanner/domain/insight_controller.dart';
import '../features/scanner/domain/insight_catalogue.dart';
import '../core/capture/automatic_label_reader.dart';
import '../features/scanner/presentation/product_info_page.dart';
import '../features/scanner/presentation/library_page.dart';
import '../features/scanner/presentation/mobile_navigation.dart';
import '../features/scanner/presentation/product_search_page.dart';
import '../features/scanner/presentation/product_results_layout.dart';
import '../features/scanner/presentation/scan_landing_page.dart';
import '../features/scanner/presentation/sources_page.dart';
import '../features/scanner/presentation/startup_page.dart';
import '../features/scanner/presentation/ui_components.dart';
import '../features/scanner/presentation/welcome_page.dart';
import 'build_info.dart';
import 'firebase_options.dart';
import 'not_found_page.dart';
import 'unlabel_theme.dart';
import 'web_appearance.dart';
import 'web_route.dart';

class UnlabelApp extends StatefulWidget {
  const UnlabelApp({
    this.repository,
    this.store,
    this.accountController,
    this.initialUri,
    this.showWelcome = true,
    super.key,
  });
  final UnlabelRepository? repository;
  final LocalStore? store;
  final AccountController? accountController;

  /// Composition can provide an entry URI; browser startup defaults to Uri.base.
  final Uri? initialUri;
  final bool showWelcome;
  @override
  State<UnlabelApp> createState() => _UnlabelAppState();
}

class _UnlabelAppState extends State<UnlabelApp> {
  ThemeMode _themeMode = ThemeMode.light;
  int _appearanceRevision = 0;
  bool _loading = true, _welcome = true, _welcomeDismissed = false;
  bool _missingPageRecovered = false;
  late final UnlabelRepository _repository;
  late final LocalStore _store;
  late final AccountController _account;
  late final ProfileMediaController _profileMedia;
  bool _showSignInReturn = false;
  bool _accountRestored = false;
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  String? _identity;
  String? _accountData;
  int _libraryRevision = 0;
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
    _account =
        widget.accountController ??
        AccountController(
          auth: _accountAuth(),
          api: AccountSyncApi(baseUrl: BuildInfo.backendBaseUrl),
          guestStore: _store,
          preferences: _store.preferences,
        );
    _identity = _account.identity?.uid;
    _showSignInReturn = isAccountSignInReturnUri(
      widget.initialUri ?? Uri.base,
      rawUrl: widget.initialUri == null ? currentWebEntryUrl : null,
    );
    if (_showSignInReturn) clearAuthActionUrl();
    _profileMedia = ProfileMediaController(
      auth: _account.auth,
      preferences: _store.preferences,
      repository: widget.accountController == null
          ? _profileRepository()
          : null,
    );
    unawaited(_profileMedia.start());
    _account.addListener(_accountChanged);
    unawaited(_restoreAccount());
    unawaited(_restore());
  }

  Future<void> _restoreAccount() async {
    try {
      await _account.start();
    } finally {
      if (mounted) setState(() => _accountRestored = true);
    }
  }

  AccountAuth _accountAuth() {
    try {
      return FirebaseAccountAuth(
        options: UnlabelFirebaseOptions.currentPlatform,
        googleServerClientId: UnlabelFirebaseOptions.googleServerClientId,
      );
    } on UnsupportedError {
      return UnavailableAccountAuth();
    }
  }

  FirebaseProfileMediaRepository? _profileRepository() {
    try {
      return FirebaseProfileMediaRepository(
        options: UnlabelFirebaseOptions.currentPlatform,
      );
    } on UnsupportedError {
      return null;
    }
  }

  ScannerAuth _scannerAuth() {
    try {
      return FirebaseScannerAuth(
        options: UnlabelFirebaseOptions.currentPlatform,
      );
    } on UnsupportedError {
      return const UnavailableScannerAuth();
    }
  }

  void _accountChanged() {
    if (!mounted) return;
    final identity = _account.identity?.uid;
    if (identity != _identity) {
      _identity = identity;
      // Old forms/reports retain the previous owner's storage object.
      _navigator.currentState?.popUntil((route) => route.isFirst);
    }
    final data = _account.localData?.encoded;
    if (data != _accountData) {
      _accountData = data;
      _libraryRevision++;
    }
    setState(() {});
  }

  Future<void> _restore() async {
    final revision = _appearanceRevision;
    String appearance = 'light';
    try {
      appearance = await _store.appearance();
    } on AppFailure {
      /* Light default. */
    }
    final welcome = widget.showWelcome && !await _store.welcomeCompleted();
    if (!mounted) return;
    setState(() {
      if (revision == _appearanceRevision) {
        _themeMode = ThemeMode.values.byName(appearance);
        setWebAppearance(appearance);
      }
      _welcome = welcome && !_missingPageRecovered && !_welcomeDismissed;
      _loading = false;
    });
  }

  Future<void> _continue() async {
    // A delayed initial read must not restore Welcome after a root auth exit.
    _welcomeDismissed = true;
    try {
      await _store.completeWelcome();
      unawaited(UiFeedback.confirmed());
    } on AppFailure catch (error) {
      _messenger.currentState?.showSnackBar(
        SnackBar(content: Text(error.userMessage)),
      );
    }
    if (mounted) setState(() => _welcome = false);
  }

  Future<void> _welcomeSignIn() async {
    final context = _navigator.currentContext;
    if (context == null) return;
    await ProfilePage.showSignIn(context, _account, fromProfile: false);
    if (mounted && _account.identity != null) await _continue();
  }

  Future<void> _setAppearance(ThemeMode mode) async {
    _appearanceRevision++;
    try {
      await _store.setAppearance(mode.name);
      if (!mounted) return;
      setState(() => _themeMode = mode);
      setWebAppearance(mode.name);
      unawaited(UiFeedback.selection());
    } on AppFailure catch (error) {
      _messenger.currentState?.showSnackBar(
        SnackBar(content: Text(error.userMessage)),
      );
    }
  }

  @override
  void dispose() {
    _profileMedia.dispose();
    _account.removeListener(_accountChanged);
    if (widget.accountController == null) {
      _account.dispose();
      _account.auth.dispose();
      _account.api.close();
    }
    if (widget.repository == null) _repository.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Unlabel',
    navigatorKey: _navigator,
    scaffoldMessengerKey: _messenger,
    debugShowCheckedModeBanner: false,
    theme: UnlabelTheme.forBrightness(Brightness.light),
    darkTheme: UnlabelTheme.forBrightness(Brightness.dark),
    themeMode: _themeMode,
    initialRoute: _showSignInReturn
        ? '/'
        : isMissingWebPage
        ? '/not-found'
        : null,
    builder: (context, child) => ProfileMediaScope(
      controller: _profileMedia,
      child: ArtworkWarmup(
        welcome: _welcome,
        child: _RootPageScope(buildPage: _rootPage, child: child!),
      ),
    ),
    onGenerateInitialRoutes: (name) => [_pageRoute(RouteSettings(name: name))],
    onGenerateRoute: _pageRoute,
  );

  Route<void> _pageRoute(RouteSettings settings) {
    // Recovery belongs to the route, not to the account-keyed client state.
    // A fresh unknown route must still show its own missing-page screen.
    var missing = settings.name != '/';
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) => _RootPageScope.of(context).buildPage(missing, () {
        missing = false;
        // Entering the app from recovery stays on Home on later rebuilds.
        _missingPageRecovered = true;
        if (_welcome) setState(() => _welcome = false);
      }),
    );
  }

  void _finishSignInReturn() {
    setState(() {
      _showSignInReturn = false;
      _welcome = false;
    });
    unawaited(_continue());
  }

  Widget _rootPage(bool missing, VoidCallback onRecovered) {
    if (_showSignInReturn) {
      // The Firebase return carries no reset outcome and cannot choose a UID.
      // Finish SDK session restoration before deciding which account UI to show.
      if (!_accountRestored) {
        return kIsWeb ? const Scaffold() : const StartupPage();
      }
      if (_account.identity != null) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            leading: IconButton(
              key: const ValueKey('account-return-home'),
              tooltip: 'Back to Unlabel',
              onPressed: _finishSignInReturn,
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          body: ProfilePage(
            controller: _account,
            onContinue: _finishSignInReturn,
            embedded: true,
            showHeader: false,
            themeMode: _themeMode,
            onThemeModeChanged: (mode) => unawaited(_setAppearance(mode)),
          ),
        );
      }
      return AuthPage(
        controller: _account,
        fromProfile: false,
        onComplete: _finishSignInReturn,
      );
    }
    return _loading && !missing && !_missingPageRecovered
        ? kIsWeb
              ? const Scaffold()
              : const StartupPage()
        : _welcome && !missing
        ? WelcomePage(
            onContinue: () => unawaited(_continue()),
            onSignIn: () => unawaited(_welcomeSignIn()),
          )
        : _ClientHome(
            key: ValueKey(_identity ?? 'guest'),
            repository: _repository,
            store: _account.activeStore,
            account: _account,
            libraryRevision: _libraryRevision,
            themeMode: _themeMode,
            onThemeModeChanged: (mode) => unawaited(_setAppearance(mode)),
            showNotFound: missing,
            onMissingPageRecovered: onRecovered,
          );
  }
}

/// Keeps routed shells current when appearance, restored state or identity changes.
class _RootPageScope extends InheritedWidget {
  const _RootPageScope({required this.buildPage, required super.child});
  final Widget Function(bool missing, VoidCallback onRecovered) buildPage;
  static _RootPageScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RootPageScope>()!;
  @override
  bool updateShouldNotify(_RootPageScope oldWidget) => true;
}

class _ClientHome extends StatefulWidget {
  const _ClientHome({
    required this.repository,
    required this.store,
    required this.account,
    required this.libraryRevision,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onMissingPageRecovered,
    this.showNotFound = false,
    super.key,
  });
  final UnlabelRepository repository;
  final LocalStore store;
  final AccountController account;
  final int libraryRevision;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onMissingPageRecovered;
  final bool showNotFound;
  @override
  State<_ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<_ClientHome> with WidgetsBindingObserver {
  late int _tab = widget.showNotFound ? -1 : 0;
  int _sourcesPreviousTab = 0;
  int _refreshKey = 0;
  bool _searching = false;
  final _searchFocus = FocusNode();
  late final _insightController = InsightController(
    preferences: widget.store.preferences,
  );
  // This state is keyed by verified account UID/guest. Confirmation envelopes
  // never leave memory, and disposal on sign-out/account changes drops them.
  final _comparisonReports = <ProductReport>[];

  void _fromResults(VoidCallback action) {
    if (!mounted) return;
    final shellRoute = ModalRoute.of(context);
    Navigator.of(context)
        .popUntil((route) => route == shellRoute || route.isFirst);
    action();
  }

  ResultsNavigation get _resultNavigation => ResultsNavigation(
    home: () => _fromResults(() {
      _closeSearch();
      _selectTab(0);
    }),
    scan: () => _fromResults(() {
      _closeSearch();
      _selectTab(1);
    }),
    history: () => _fromResults(() => _library(2)),
    learn: () => _fromResults(_insights),
    products: () => _fromResults(_search),
    profile: () => _fromResults(_profile),
    notifications: _notifications,
  );

  ShellNavigation get _shellNavigation => ShellNavigation(
    selectedIndex: _tab,
    onSelect: (index) => _fromResults(() {
      _closeSearch();
      _selectTab(index);
    }),
    onHistory: () => _fromResults(() => _library(2)),
    onInsights: () => _fromResults(_insights),
    onSources: () => _fromResults(_sources),
    onSearch: () => _fromResults(_search),
    onProfile: () => _fromResults(_profile),
    onNotifications: _notifications,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_insightController.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _insightController.refreshDay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _insightController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _closeSearch() {
    _searchFocus.unfocus();
    setState(() => _searching = false);
  }

  void _search() {
    _leaveMissingPage();
    setState(() => _searching = true);
    // The input is already attached, so focus stays in the initiating tap.
    // Mobile browsers may reject a soft keyboard opened after route animation.
    _searchFocus.requestFocus();
  }

  void _selectTab(int value) {
    if (_tab == value) return;
    _leaveMissingPage();
    unawaited(UiFeedback.selection());
    setState(() => _tab = value);
  }

  void _leaveMissingPage() {
    if (_tab == -1) {
      clearMissingWebPage();
      widget.onMissingPageRecovered();
      setState(() => _tab = 0);
    }
  }

  @override
  void didUpdateWidget(covariant _ClientHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.libraryRevision != widget.libraryRevision) _refreshKey++;
  }

  void _changed() {
    if (mounted) setState(() => _refreshKey++);
  }

  Future<void> _record(ProductReport report) async {
    if (report.confirmedComparisonObservation != null) {
      _comparisonReports.removeWhere((entry) => entry.id == report.id);
      _comparisonReports.insert(0, report);
      if (_comparisonReports.length > 40) _comparisonReports.removeLast();
    }
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

  Future<void> _openReport(
    ProductReport report, {
    bool record = false,
    List<String> frontClaims = const [],
  }) async {
    if (!mounted) return;
    if (record) unawaited(_record(report));
    await Navigator.of(context).push<void>(
      ShellContentRoute<void>(
        context: context,
        builder: (_) => ProductInfoPage.report(
          frontClaims: frontClaims,
          repository: widget.repository,
          navigation: _resultNavigation,
          report: report,
          store: widget.store,
          onChanged: _changed,
        ),
      ),
    );
  }

  Future<void> _lookup(bool barcode) async {
    if (barcode) {
      _selectTab(1);
    } else {
      _search();
    }
  }

  Future<void> _scanResult(AutomaticScanResult result, Uint8List? front) async {
    if (!mounted) return;
    if (result.report != null) return _openReport(result.report!, record: true);
    // A known barcode can open its single compatible source directly. Text-only
    // matches stay optional choices, and never replace the machine-read label.
    if (result.label == null && result.candidates.length == 1) {
      final product = await widget.repository.loadResearchProduct(
        result.candidates.single.entryId,
      );
      if (!mounted) return;
      return Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ProductInfoPage.research(
            repository: widget.repository,
            product: product,
            navigation: _resultNavigation,
          ),
        ),
      );
    }
    if (result.label != null) {
      return Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ProductInfoPage.extracted(
            navigation: _resultNavigation,
            label: result.label!,
            photo: front,
            localFallback: result.localFallback,
            repository: widget.repository,
            barcode: result.barcode,
            candidates: result.candidates,
            catalogueCandidates: result.catalogueCandidates,
            onOpenReport: (report) => _openReport(
              report,
              record: true,
              frontClaims: result.label!.frontClaims,
            ),
          ),
        ),
      );
    }
    if (result.candidates.isEmpty && result.barcode != null) {
      return Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ProductInfoPage.barcode(
            barcode: result.barcode!,
            repository: widget.repository,
            navigation: _resultNavigation,
          ),
        ),
      );
    }
    final candidate = await showModalBottomSheet<ResearchedCandidate>(
      context: context,
      useSafeArea: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Choose your package')),
          for (final candidate in result.candidates)
            ListTile(
              title: Text(candidate.name),
              subtitle: Text(
                [
                  candidate.brand,
                  candidate.variant,
                  candidate.quantity,
                ].whereType<String>().join(' · '),
              ),
              onTap: () => Navigator.pop(context, candidate),
            ),
        ],
      ),
    );
    if (candidate != null && mounted) {
      final product = await widget.repository.loadResearchProduct(
        candidate.entryId,
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ProductInfoPage.research(
            repository: widget.repository,
            product: product,
            navigation: _resultNavigation,
          ),
        ),
      );
    }
  }

  void _library(int oldTab) {
    _leaveMissingPage();
    if (_searching) _closeSearch();
    if (oldTab == 1) {
      _selectTab(3);
      return;
    }
    // History is a peer destination on desktop, just like Home and Saved.
    // Replacing only the body keeps the existing header/sidebar stationary.
    if (_desktopLayout) {
      _selectTab(4);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShellPage(
          title: 'History',
          selectedIndex: 4,
          navigation: _shellNavigation,
          body: LibraryPage(
            saved: false,
            showTitle: false,
            store: widget.store,
            refreshKey: _refreshKey,
            onOpenReport: _openReport,
            onLookup: () => _fromResults(() => _lookup(true)),
            onChanged: _changed,
          ),
        ),
      ),
    );
  }

  void _appearance() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            for (final mode in ThemeMode.values)
              ListTile(
                title: Text(switch (mode) {
                  ThemeMode.light => 'Light',
                  ThemeMode.dark => 'Dark',
                  ThemeMode.system => 'System',
                }),
                trailing: widget.themeMode == mode
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  widget.onThemeModeChanged(mode);
                },
              ),
          ],
        ),
      ),
    ),
  );
  void _about() => showAboutDialog(
    context: context,
    applicationName: 'Unlabel',
    applicationVersion: '${BuildInfo.version} (${BuildInfo.buildNumber})',
    applicationIcon: const AppSymbol(size: 64),
    children: const [
      Text('Know Beyond the Label'),
      SizedBox(height: 16),
      Text(
        'Guest history and saved products stay on this device. Signing in enables private account sync. Confirmed structured public package facts are stored separately.',
      ),
      SizedBox(height: 12),
      Text(
        'Solar icons by 480 Design — CC BY 4.0. Bundled brand typeface: Nunito — SIL Open Font License.',
      ),
    ],
  );
  void _profile() {
    _leaveMissingPage();
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            toolbarHeight: 72,
            title: const Text(
              'Profile',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
          ),
          body: ProfilePage(
            controller: widget.account,
            embedded: true,
            showHeader: false,
            themeMode: widget.themeMode,
            onThemeModeChanged: widget.onThemeModeChanged,
            onSaved: () {
              Navigator.of(context).pop();
              _selectTab(3);
            },
            onScans: () {
              Navigator.of(context).pop();
              _library(2);
            },
            onCompare: () {
              Navigator.of(context).pop();
              _selectTab(2);
            },
            onContinue: () => Navigator.of(context).pop(),
            onAppearance: _appearance,
            onAbout: _about,
          ),
        ),
      ),
    );
  }

  void _insights() {
    _insightController.setTopic(InsightTopic.all);
    _selectTab(5);
  }

  void _sources() {
    if (_tab != 6) _sourcesPreviousTab = _tab < 0 ? 0 : _tab;
    if (_searching) _closeSearch();
    _selectTab(6);
  }

  void _sourceBack() => _selectTab(_sourcesPreviousTab);

  bool get _desktopLayout =>
      MediaQuery.sizeOf(context).width >= 1200 &&
      MediaQuery.textScalerOf(context).scale(14) <= 21;

  void _notifications() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Notifications'),
      content: const Text(
        'You have no notifications. Product reminders are not enabled yet.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
    final desktop = MediaQuery.sizeOf(context).width >= 1200 && !largeText;
    return PopScope(
      canPop: !_searching && _tab < 4,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _searching) {
          _closeSearch();
        } else if (!didPop && _tab >= 4) {
          if (_tab == 6) {
            _sourceBack();
          } else {
            _selectTab(0);
          }
        }
      },
      child: AppShellScope(
        navigation: _shellNavigation,
        child: Stack(
          children: [
            Offstage(
              offstage: _searching,
              child: Row(
                children: [
                  if (desktop)
                    DesktopNavigation(
                      selectedIndex: _tab,
                      onSelect: _selectTab,
                      onHistory: () => _library(2),
                      onInsights: _insights,
                    ),
                  Expanded(
                    child: Scaffold(
                      extendBody: true,
                      appBar: desktop
                          ? DesktopTopBar(
                              onSearch: _search,
                              onProfile: _profile,
                              onNotifications: _notifications,
                            )
                          : AppBar(
                              leading: _tab >= 4
                                  ? BackButton(
                                      onPressed: _tab == 6
                                          ? _sourceBack
                                          : () => _selectTab(0),
                                    )
                                  : null,
                              toolbarHeight: largeText ? 112 : 64,
                              title: _tab == 6
                                  ? const Text('Our Sources')
                                  : _tab == 5
                                  ? const Text('Insights')
                                  : _tab == 4
                                  ? const Text('History')
                                  : BrandHomeButton(
                                      key: const Key('mobile-brand-home'),
                                      onPressed: () => _selectTab(0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  'Unlabel',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: theme
                                                      .textTheme
                                                      .headlineMedium
                                                      ?.copyWith(fontSize: 30),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              if (!largeText)
                                                const BrandLeaf(size: 30),
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
                                    ),
                              actions: [
                                IconButton(
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  onPressed: () => _lookup(false),
                                  tooltip: 'Search products',
                                  icon: const FeatureIcon('magnifer'),
                                ),
                                IconButton(
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  onPressed: _profile,
                                  tooltip: 'Profile',
                                  icon: const ExcludeSemantics(
                                    child: AccountAvatar(size: 40),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                      body: switch (_tab) {
                        -1 => NotFoundPage(onHome: () => _selectTab(0)),
                        0 => HomePage(
                          store: widget.store,
                          refreshKey: _refreshKey,
                          onLookup: _lookup,
                          onEnterLabel: () => _selectTab(1),
                          onCompare: () => _selectTab(2),
                          onOpenReport: _openReport,
                          onLibrary: _library,
                          desktop: desktop,
                          insightController: _insightController,
                          onInsights: _insights,
                          onSources: _sources,
                        ),
                        1 => ScanLandingPage(
                          reader: AutomaticLabelReader(widget.repository),
                          onResult: _scanResult,
                        ),
                        2 => ComparePage(
                          store: widget.store,
                          repository: widget.repository,
                          onOpenReport: _openReport,
                          sessionReports: List.unmodifiable(_comparisonReports),
                        ),
                        4 => LibraryPage(
                          saved: false,
                          showTitle: desktop,
                          store: widget.store,
                          refreshKey: _refreshKey,
                          onOpenReport: _openReport,
                          onLookup: () => _lookup(true),
                          onChanged: _changed,
                        ),
                        5 => InsightsPage(
                          controller: _insightController,
                          embedded: true,
                        ),
                        6 => SourcesPage(embedded: true, onBack: _sourceBack),
                        _ => LibraryPage(
                          saved: true,
                          store: widget.store,
                          refreshKey: _refreshKey,
                          onOpenReport: _openReport,
                          onLookup: () => _lookup(true),
                          onChanged: _changed,
                        ),
                      },
                      bottomNavigationBar:
                          desktop ||
                              _tab >= 4 ||
                              MediaQuery.viewInsetsOf(context).bottom > 0
                          ? null
                          : MobileNavigation(
                              selectedIndex: _tab,
                              onDestinationSelected: _selectTab,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Visibility(
              visible: _searching,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              maintainFocusability: true,
              child: TickerMode(
                enabled: _searching,
                child: ScaffoldMessenger(
                  child: ProductSearchPage(
                    resultNavigation: _resultNavigation,
                    active: _searching,
                    repository: widget.repository,
                    focusNode: _searchFocus,
                    autofocus: false,
                    onClose: _closeSearch,
                    onOpenReport: (report) => _openReport(report, record: true),
                    onEnterLabel: () {
                      _closeSearch();
                      _selectTab(1);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
