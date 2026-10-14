// Developer-only entry point for screenshots of the real account pages.
// Production main.dart never imports this file. All identity and preferences
// are synthetic, memory-only fixtures; no Firebase or API connection is made.
// Example: ?screen=signup&dark=true&scale=2
// screen=forgot/sent drives the real visible reset controls with a synthetic
// address; it neither adds a production hook nor sends an email.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/accounts/account_auth.dart';
import 'package:unlabel/core/accounts/account_controller.dart';
import 'package:unlabel/core/accounts/account_data.dart';
import 'package:unlabel/core/accounts/account_sync_api.dart';
import 'package:unlabel/core/models/app_failure.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/account/presentation/auth_page.dart';
import 'package:unlabel/features/account/presentation/profile_page.dart';

class _MemoryPreferences implements PreferencesAdapter {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];
  @override
  Future<void> write(String key, String value) async => _values[key] = value;
  @override
  Future<void> remove(String key) async => _values.remove(key);
}

class _PreviewAuth extends AccountAuth {
  _PreviewAuth({required this.signedIn});
  final bool signedIn;

  @override
  AccountIdentity? get identity => signedIn
      ? const AccountIdentity(
          uid: 'synthetic-visual-preview-only',
          email: 'scanner@example.invalid',
          displayName: 'Sample Scanner',
          googleEmail: 'scanner@example.invalid',
          googleDisplayName: 'Sample Scanner',
          providers: {'google.com', 'password'},
        )
      : null;

  static const _disabled = AppFailure(
    'preview_auth_disabled',
    'This is a visual preview. Account changes are disabled.',
  );
  @override
  Future<void> start() async {}
  @override
  Future<void> signIn(String email, String password) async => throw _disabled;
  @override
  Future<void> signInGoogle() async => throw _disabled;
  @override
  Future<void> create(String email, String password) async => throw _disabled;
  // This only opens the neutral confirmation UI; it sends no message.
  @override
  Future<void> resetPassword(String email) async {}
  @override
  Future<void> signOut() async => throw _disabled;
  @override
  Future<String> token(String expectedUid) async => throw _disabled;
}

class _DisabledSync implements AccountSyncTransport {
  @override
  Future<bool> available() async => false;
  @override
  Future<AccountSnapshot> fetch(String token) async =>
      throw StateError('The visual preview cannot fetch private data.');
  @override
  Future<AccountSnapshot> put(String token, AccountMutation mutation) async =>
      throw StateError('The visual preview cannot upload private data.');
  @override
  void cancelAll() {}
  @override
  void close() {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Expose real Flutter semantics for local browser geometry/keyboard checks.
  SemanticsBinding.instance.ensureSemantics();
  final query = Uri.base.queryParameters;
  final screen = query['screen'] ?? 'signin';
  final preferences = _MemoryPreferences();
  final auth = _PreviewAuth(signedIn: screen == 'profile');
  final account = AccountController(
    auth: auth,
    api: _DisabledSync(),
    guestStore: LocalStore(preferences: preferences),
    preferences: preferences,
  );
  await account.start();
  runApp(
    _PreviewApp(
      account: account,
      screen: screen,
      dark: query['dark'] == 'true',
      scale: (double.tryParse(query['scale'] ?? '') ?? 1)
          .clamp(1, 2)
          .toDouble(),
    ),
  );
}

class _PreviewApp extends StatefulWidget {
  const _PreviewApp({
    required this.account,
    required this.screen,
    required this.dark,
    required this.scale,
  });
  final AccountController account;
  final String screen;
  final bool dark;
  final double scale;

  @override
  State<_PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<_PreviewApp> {
  @override
  void initState() {
    super.initState();
    if (widget.screen == 'forgot' || widget.screen == 'sent') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openResetPreview());
    }
  }

  Widget? _control(String key) {
    Widget? found;
    void visit(Element element) {
      if (element.widget.key == ValueKey(key)) found = element.widget;
      if (found == null) element.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  Future<void> _openResetPreview() async {
    if (!mounted) return;
    final forgot = _control('auth-forgot');
    if (forgot is TextButton) {
      forgot.onPressed?.call();
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || widget.screen != 'sent') return;
    final email = _control('auth-email');
    if (email is! TextFormField) return;
    email.controller?.text = 'scanner@example.invalid';
    final submit = _control('account-submit');
    if (submit is FilledButton) submit.onPressed?.call();
  }

  @override
  void dispose() {
    widget.account.dispose();
    widget.account.auth.dispose();
    widget.account.api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: UnlabelTheme.forBrightness(
      widget.dark ? Brightness.dark : Brightness.light,
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(widget.scale),
        disableAnimations: Uri.base.queryParameters['motion'] != 'true',
      ),
      child: child!,
    ),
    home: widget.screen == 'profile'
        ? ProfilePage(controller: widget.account, onContinue: () {})
        : AuthPage(
            controller: widget.account,
            create: widget.screen == 'signup',
            fromProfile: false,
            onComplete: () {},
          ),
  );
}
