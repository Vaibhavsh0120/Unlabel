import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/accounts/account_auth.dart';
import 'package:unlabel/core/accounts/account_controller.dart';
import 'package:unlabel/core/accounts/account_data.dart';
import 'package:unlabel/core/accounts/account_sync_api.dart';
import 'package:unlabel/core/accounts/password_policy.dart';
import 'package:unlabel/core/models/app_failure.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/core/widgets/brand_mark.dart';
import 'package:unlabel/features/account/presentation/auth_page.dart';

class _Preferences implements PreferencesAdapter {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

class _NoSync implements AccountSyncTransport {
  @override
  Future<bool> available() async => false;
  @override
  Future<AccountSnapshot> fetch(String token) async =>
      throw StateError('Auth forms must not fetch account reports.');
  @override
  Future<AccountSnapshot> put(String token, AccountMutation mutation) async =>
      throw StateError('Auth forms must not upload account reports.');
  @override
  void cancelAll() {}
  @override
  void close() {}
}

class _Controller extends AccountController {
  _Controller()
    : super(
        auth: UnavailableAccountAuth(),
        api: _NoSync(),
        guestStore: LocalStore(preferences: _Preferences()),
        preferences: _Preferences(),
      );
  int signIns = 0, creates = 0, google = 0, resets = 0, confirmations = 0;
  String? email, password, name, receivedCode;
  AppFailure? failure;
  Completer<void>? operation;
  Completer<String>? verification;

  Future<void> _finish() async {
    if (operation != null) await operation!.future;
    if (failure != null) throw failure!;
  }

  @override
  Future<void> signIn(String email, String password) async {
    signIns++;
    this.email = email;
    this.password = password;
    await _finish();
  }

  @override
  Future<void> create(
    String email,
    String password, {
    String? displayName,
  }) async {
    creates++;
    this.email = email;
    this.password = password;
    name = displayName;
    await _finish();
  }

  @override
  Future<void> signInGoogle() async {
    google++;
    await _finish();
  }

  @override
  Future<void> resetPassword(String email) async {
    resets++;
    this.email = email;
    await _finish();
  }

  @override
  Future<String> verifyPasswordResetCode(String code) async {
    receivedCode = code;
    if (verification != null) return verification!.future;
    if (failure != null) throw failure!;
    return 'synthetic@example.invalid';
  }

  @override
  Future<void> confirmPasswordReset(String code, String password) async {
    confirmations++;
    receivedCode = code;
    this.password = password;
    await _finish();
  }

  @override
  void dispose() {
    auth.dispose();
    super.dispose();
  }
}

Future<void> _open(
  WidgetTester tester,
  _Controller controller, {
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool create = false,
  bool fromProfile = true,
  String? code,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: UnlabelTheme.forBrightness(brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => AuthPage(
                  controller: controller,
                  create: create,
                  fromProfile: fromProfile,
                  resetCode: code,
                ),
              ),
            ),
            child: const Text('Open account'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open account'));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _accountAction(
  WidgetTester tester,
  String key,
  String label,
) async {
  final direct = find.byKey(ValueKey(key));
  if (direct.evaluate().isNotEmpty) {
    await _tap(tester, direct);
  } else {
    await _tap(tester, find.byKey(const ValueKey('auth-options')));
    await _tap(tester, find.text(label).last);
  }
}

void _expectSingleScreen(
  WidgetTester tester,
  Size size, {
  double keyboard = 0,
}) {
  final page = find.byType(AuthPage);
  expect(
    find.descendant(of: page, matching: find.byType(SingleChildScrollView)),
    findsNothing,
  );
  final controls = find.descendant(
    of: page,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is TextFormField ||
          widget is ButtonStyleButton ||
          widget is IconButton,
    ),
  );
  for (final element in controls.evaluate()) {
    final bounds = tester.getRect(
      find.byElementPredicate((candidate) => identical(candidate, element)),
    );
    expect(
      bounds.left,
      greaterThanOrEqualTo(-.1),
      reason: element.widget.toStringShort(),
    );
    expect(
      bounds.top,
      greaterThanOrEqualTo(-.1),
      reason: element.widget.toStringShort(),
    );
    expect(
      bounds.right,
      lessThanOrEqualTo(size.width + .1),
      reason: element.widget.toStringShort(),
    );
    expect(
      bounds.bottom,
      lessThanOrEqualTo(size.height - keyboard + .1),
      reason: element.widget.toStringShort(),
    );
  }
  expect(tester.takeException(), isNull);
}

void main() {
  test('new password policy rejects weak and common values consistently', () {
    expect(validateNewPassword('Short1'), isNotNull);
    expect(validateNewPassword('LongButNoNumber'), isNotNull);
    expect(validateNewPassword('123456789012'), isNotNull);
    expect(
      validateNewPassword('PASSWORD123'),
      'Choose a less common password.',
    );
    expect(validateNewPassword('UniqueField42'), isNull);
  });

  for (final size in [
    const Size(320, 700),
    const Size(390, 844),
    const Size(1440, 900),
  ]) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'auth layouts stay reachable at $size $brightness text $scale',
          (tester) async {
            final controller = _Controller();
            addTearDown(controller.dispose);
            await _open(
              tester,
              controller,
              size: size,
              brightness: brightness,
              textScale: scale,
            );
            expect(find.byKey(const ValueKey('auth-title')), findsOneWidget);
            _expectSingleScreen(tester, size);
            await _tap(tester, find.byKey(const ValueKey('auth-mode-switch')));
            expect(find.byKey(const ValueKey('auth-name')), findsOneWidget);
            _expectSingleScreen(tester, size);
            await tester.ensureVisible(
              find.byKey(const ValueKey('account-submit')),
            );
            expect(tester.takeException(), isNull);
            await _tap(tester, find.byKey(const ValueKey('auth-mode-switch')));
            await _accountAction(tester, 'auth-forgot', 'Forgot password?');
            expect(find.byKey(const ValueKey('auth-email')), findsOneWidget);
            await tester.enterText(
              find.byKey(const ValueKey('auth-email')),
              'synthetic@example.invalid',
            );
            await _tap(tester, find.byKey(const ValueKey('account-submit')));
            expect(find.byKey(const ValueKey('auth-title')), findsOneWidget);
            _expectSingleScreen(tester, size);
            expect(
              find.textContaining('If this email has an account'),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            expect(controller.resets, 1);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }

  testWidgets('profile origin uses X and closes without authenticating', (
    tester,
  ) async {
    final controller = _Controller();
    addTearDown(controller.dispose);
    await _open(tester, controller);
    expect(find.byType(BrandLeaf), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('auth-close')));
    expect(find.text('Open account'), findsOneWidget);
    expect(controller.signIns + controller.creates + controller.google, 0);
  });

  testWidgets(
    'sign-in accepts legacy password and prevents repeated pending action',
    (tester) async {
      final controller = _Controller()..operation = Completer<void>();
      addTearDown(controller.dispose);
      await _open(tester, controller);
      await tester.enterText(
        find.byKey(const ValueKey('auth-email')),
        ' synthetic@example.invalid ',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-password')),
        'short',
      );
      final submit = find.byKey(const ValueKey('account-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      expect(controller.signIns, 1);
      expect(controller.email, 'synthetic@example.invalid');
      expect(controller.password, 'short');
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('auth-close')))
            .onPressed,
        isNull,
      );
      controller.operation!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Open account'), findsOneWidget);
    },
  );

  testWidgets('signup validates name and new password then sends name once', (
    tester,
  ) async {
    final controller = _Controller();
    addTearDown(controller.dispose);
    await _open(tester, controller, create: true);
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'synthetic@example.invalid',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'password123',
    );
    await _tap(tester, find.byKey(const ValueKey('account-submit')));
    expect(find.text('Enter your name.'), findsOneWidget);
    expect(find.text('Choose a less common password.'), findsOneWidget);
    expect(controller.creates, 0);
    await tester.enterText(
      find.byKey(const ValueKey('auth-name')),
      ' Synthetic Scanner ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'UniqueField42',
    );
    await _tap(tester, find.byKey(const ValueKey('account-submit')));
    expect(controller.creates, 1);
    expect(controller.name, 'Synthetic Scanner');
    expect(find.text('Open account'), findsOneWidget);
  });

  testWidgets('Google action preserves safe error and allows guest exit', (
    tester,
  ) async {
    final controller = _Controller()
      ..failure = const AppFailure(
        'google_cancelled',
        'Google sign-in was cancelled.',
      );
    addTearDown(controller.dispose);
    await _open(tester, controller);
    await _tap(tester, find.byKey(const ValueKey('auth-google')));
    expect(controller.google, 1);
    expect(find.text('Google sign-in was cancelled.'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('auth-guest')));
    expect(find.text('Open account'), findsOneWidget);
  });

  testWidgets('reset link must verify before password form appears', (
    tester,
  ) async {
    final controller = _Controller()..verification = Completer<String>();
    addTearDown(controller.dispose);
    // A verification spinner is intentionally pending; do not settle it.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: AuthPage(
          controller: controller,
          resetCode: 'synthetic-code',
          fromProfile: false,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Checking reset link…'), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-password')), findsNothing);
    controller.verification!.completeError(
      const AppFailure(
        'invalid_reset',
        'This reset link has expired. Request a new link.',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('auth-password')), findsNothing);
    expect(
      find.text('This reset link has expired. Request a new link.'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Request a new reset link'));
    expect(find.text('Forgot your password?'), findsOneWidget);
    expect(controller.confirmations, 0);
  });

  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    testWidgets(
      'verified reset completes only with matching strong passwords $size',
      (tester) async {
        final controller = _Controller();
        addTearDown(controller.dispose);
        await _open(
          tester,
          controller,
          size: size,
          code: 'synthetic-code',
          fromProfile: false,
        );
        expect(controller.receivedCode, 'synthetic-code');
        expect(find.text('Create a new password'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('auth-password')),
          'UniqueField42',
        );
        await tester.enterText(
          find.byKey(const ValueKey('auth-confirm-password')),
          'DifferentField42',
        );
        await _tap(tester, find.byKey(const ValueKey('account-submit')));
        expect(find.text('Your passwords don’t match.'), findsOneWidget);
        expect(controller.confirmations, 0);
        await tester.enterText(
          find.byKey(const ValueKey('auth-confirm-password')),
          'UniqueField42',
        );
        await _tap(tester, find.byKey(const ValueKey('account-submit')));
        expect(controller.confirmations, 1);
        expect(controller.password, 'UniqueField42');
        expect(find.text('Password updated!'), findsOneWidget);
        await _tap(tester, find.byKey(const ValueKey('auth-success-signin')));
        expect(find.text('Welcome back'), findsOneWidget);
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey('auth-password')),
              )
              .controller!
              .text,
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Terms and Privacy controls open readable information windows', (
    tester,
  ) async {
    final controller = _Controller();
    addTearDown(controller.dispose);
    await _open(tester, controller);
    await _tap(tester, find.text('Privacy Policy'));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.textContaining(
        'Guest history and saved products stay on this device.',
      ),
      findsOneWidget,
    );
    await _tap(tester, find.text('Close'));
    await _tap(tester, find.text('Terms'));
    expect(find.text('Using Unlabel'), findsOneWidget);
    expect(find.textContaining('An account is optional.'), findsNothing);
    expect(find.textContaining('an account is optional.'), findsOneWidget);
  });

  for (final signIn in [true, false]) {
    testWidgets(
      'root reset flow completes through ${signIn ? 'sign-in' : 'guest'} callback',
      (tester) async {
        final controller = _Controller();
        addTearDown(controller.dispose);
        String? resetCode = 'synthetic-code';
        var completed = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: UnlabelTheme.forBrightness(Brightness.light),
            home: StatefulBuilder(
              builder: (context, setState) => completed
                  ? const Scaffold(body: Text('Home restored'))
                  : AuthPage(
                      controller: controller,
                      fromProfile: false,
                      resetCode: resetCode,
                      onComplete: () => setState(() {
                        resetCode = null;
                        completed = true;
                      }),
                    ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('auth-password')),
          'UniqueField42',
        );
        await tester.enterText(
          find.byKey(const ValueKey('auth-confirm-password')),
          'UniqueField42',
        );
        await _tap(tester, find.byKey(const ValueKey('account-submit')));
        await _tap(tester, find.byKey(const ValueKey('auth-success-signin')));
        if (signIn) {
          await tester.enterText(
            find.byKey(const ValueKey('auth-email')),
            'synthetic@example.invalid',
          );
          await tester.enterText(
            find.byKey(const ValueKey('auth-password')),
            'UniqueField42',
          );
          await _tap(tester, find.byKey(const ValueKey('account-submit')));
        } else {
          await _accountAction(tester, 'auth-guest', 'Continue as guest');
        }
        expect(find.text('Home restored'), findsOneWidget);
        expect(resetCode, isNull);
        expect(controller.confirmations, 1);
        expect(controller.signIns, signIn ? 1 : 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('late sign-in completion never touches a disposed form', (
    tester,
  ) async {
    final controller = _Controller()..operation = Completer<void>();
    addTearDown(controller.dispose);
    await _open(tester, controller);
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'synthetic@example.invalid',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'UniqueField42',
    );
    final submit = find.byKey(const ValueKey('account-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    controller.operation!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final layout in [
    (const Size(360, 740), 1.0),
    (const Size(320, 568), 1.0),
    (const Size(740, 360), 1.0),
    (const Size(320, 568), 2.0),
  ]) {
    testWidgets('all six auth states fit one screen at $layout', (
      tester,
    ) async {
      final controller = _Controller();
      addTearDown(controller.dispose);
      await _open(tester, controller, size: layout.$1, textScale: layout.$2);
      _expectSingleScreen(tester, layout.$1);
      await _tap(tester, find.byKey(const ValueKey('auth-mode-switch')));
      _expectSingleScreen(tester, layout.$1);
      await _tap(tester, find.byKey(const ValueKey('auth-mode-switch')));
      await _accountAction(tester, 'auth-forgot', 'Forgot password?');
      _expectSingleScreen(tester, layout.$1);
      await tester.enterText(
        find.byKey(const ValueKey('auth-email')),
        'synthetic@example.invalid',
      );
      await _tap(tester, find.byKey(const ValueKey('account-submit')));
      expect(find.byKey(const ValueKey('auth-title')), findsOneWidget);
      _expectSingleScreen(tester, layout.$1);
      await tester.pumpWidget(const SizedBox.shrink());
      await _open(
        tester,
        controller,
        size: layout.$1,
        textScale: layout.$2,
        code: 'synthetic-code',
        fromProfile: false,
      );
      _expectSingleScreen(tester, layout.$1);
      await tester.enterText(
        find.byKey(const ValueKey('auth-password')),
        'UniqueField42',
      );
      if (find
          .byKey(const ValueKey('auth-confirm-password'))
          .evaluate()
          .isEmpty) {
        await _tap(tester, find.byKey(const ValueKey('account-submit')));
      }
      await tester.enterText(
        find.byKey(const ValueKey('auth-confirm-password')),
        'UniqueField42',
      );
      await _tap(tester, find.byKey(const ValueKey('account-submit')));
      expect(find.text('Password updated!'), findsOneWidget);
      _expectSingleScreen(tester, layout.$1);
    });
  }

  testWidgets('all empty signup validation stays inside normal phone screens', (
    tester,
  ) async {
    final controller = _Controller();
    addTearDown(controller.dispose);
    for (final size in [
      const Size(390, 844),
      const Size(360, 740),
      const Size(320, 568),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await _open(tester, controller, size: size, create: true);
      await _tap(tester, find.byKey(const ValueKey('account-submit')));
      expect(find.text('Enter your name.'), findsOneWidget);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      _expectSingleScreen(tester, size);
    }
    expect(controller.creates, 0);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'keyboard keeps active field, close and primary action visible at 320px text $scale',
      (tester) async {
        final controller = _Controller();
        addTearDown(controller.dispose);
        const size = Size(320, 568);
        await _open(tester, controller, size: size, textScale: scale);
        await tester.enterText(
          find.byKey(const ValueKey('auth-email')),
          'synthetic@example.invalid',
        );
        if (find.byKey(const ValueKey('auth-password')).evaluate().isEmpty) {
          await _tap(tester, find.byKey(const ValueKey('account-submit')));
        }
        await tester.tap(find.byKey(const ValueKey('auth-password')));
        await tester.pump();
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('auth-password')), findsOneWidget);
        expect(find.byKey(const ValueKey('auth-close')), findsOneWidget);
        _expectSingleScreen(tester, size, keyboard: 260);
        await tester.enterText(
          find.byKey(const ValueKey('auth-password')),
          'UniqueField42',
        );
        await _tap(tester, find.byKey(const ValueKey('account-submit')));
        expect(controller.signIns, 1);
        expect(find.text('Open account'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'focusing password before keyboard paging cannot skip required signup fields',
    (tester) async {
      final controller = _Controller();
      addTearDown(controller.dispose);
      const size = Size(320, 568);
      await _open(tester, controller, size: size, create: true);
      await tester.enterText(
        find.byKey(const ValueKey('auth-password')),
        'UniqueField42',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('auth-name')), findsNothing);
      await _tap(tester, find.byKey(const ValueKey('account-submit')));
      expect(controller.creates, 0);
      expect(find.byKey(const ValueKey('auth-name')), findsOneWidget);
      expect(find.text('Enter your name.'), findsOneWidget);
      _expectSingleScreen(tester, size, keyboard: 260);
      await tester.enterText(
        find.byKey(const ValueKey('auth-name')),
        'Synthetic Scanner',
      );
      await _tap(tester, find.byKey(const ValueKey('account-submit')));
      expect(find.byKey(const ValueKey('auth-email')), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('account-submit')));
      expect(controller.creates, 0);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      _expectSingleScreen(tester, size, keyboard: 260);
      await tester.enterText(
        find.byKey(const ValueKey('auth-email')),
        'synthetic@example.invalid',
      );
      await _tap(tester, find.byKey(const ValueKey('account-submit')));
      await _tap(tester, find.byKey(const ValueKey('account-submit')));
      expect(controller.creates, 1);
      expect(controller.email, 'synthetic@example.invalid');
      expect(controller.name, 'Synthetic Scanner');
    },
  );
}
