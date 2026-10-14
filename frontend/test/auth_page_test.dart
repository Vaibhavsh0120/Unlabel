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
import 'package:unlabel/features/account/presentation/auth_scene.dart';
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
  int signIns = 0, creates = 0, google = 0, resets = 0;
  String? email, password, name;
  AppFailure? failure;
  Completer<void>? operation;

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
  bool reducedMotion = true,
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
          disableAnimations: reducedMotion,
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
  if (reducedMotion) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }
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

Future<void> _fill(WidgetTester tester, String key, String value) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

void _expectWidth(WidgetTester tester, Size size) {
  for (final element in find.byType(TextFormField).evaluate()) {
    final rect = tester.getRect(
      find.byElementPredicate((candidate) => candidate == element),
    );
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(size.width));
  }
  // The test binding reports any uncaught layout errors with their render tree.
}

TextField _input(WidgetTester tester, String key) => tester.widget<TextField>(
  find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextField),
  ),
);

void main() {
  test('new password policy still rejects weak and common passwords', () {
    expect(validateNewPassword('Short1'), isNotNull);
    expect(validateNewPassword('LongButNoNumber'), isNotNull);
    expect(
      validateNewPassword('password123'),
      'Choose a less common password.',
    );
    expect(validateNewPassword('UniqueField42'), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(426, 923),
    const Size(768, 1024),
    const Size(820, 1180),
    const Size(1024, 768),
    const Size(1180, 820),
    const Size(960, 720),
    const Size(1536, 1024),
  ]) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'all auth flows remain reachable at $size $brightness text $scale',
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
            expect(find.byType(AuthScene), findsOneWidget);
            await tester.ensureVisible(
              find.byKey(const ValueKey('account-submit')),
            );
            _expectWidth(tester, size);
            await _tap(tester, find.byKey(const ValueKey('auth-mode-switch')));
            expect(find.byType(TextFormField), findsNWidgets(4));
            expect(find.text('Full name'), findsOneWidget);
            expect(find.byKey(const ValueKey('auth-last-name')), findsNothing);
            await _tap(tester, find.byKey(const ValueKey('account-submit')));
            expect(controller.creates, 0);
            expect(find.text('Enter your name.'), findsOneWidget);
            _expectWidth(tester, size);
            await _tap(tester, find.byKey(const ValueKey('auth-mode-switch')));
            await _accountAction(tester, 'auth-forgot', 'Forgot password?');
            await _fill(tester, 'auth-email', 'synthetic@example.invalid');
            await _tap(tester, find.byKey(const ValueKey('account-submit')));
            expect(controller.resets, 1);
            expect(
              find.textContaining('If this email has an account'),
              findsOneWidget,
            );
            expect(find.byType(TextFormField), findsNothing);
            _expectWidth(tester, size);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }

  for (final size in [
    const Size(960, 720),
    const Size(1366, 768),
    const Size(1536, 1024),
  ]) {
    testWidgets('desktop cards are equal, centered and never scroll at $size', (
      tester,
    ) async {
      final controller = _Controller();
      addTearDown(controller.dispose);
      await _open(tester, controller, size: size);
      final card = find.byKey(const ValueKey('auth-form-card'));
      final login = tester.getRect(card);
      expect(login.center.dx, closeTo(size.width * .7775, 1));
      expect(find.byType(SingleChildScrollView), findsNothing);
      for (final create in [false, true]) {
        if (create) {
          await _tap(tester, find.byKey(const ValueKey('auth-mode-switch')));
        }
        final rect = tester.getRect(card);
        expect(rect.width, closeTo(login.width, .01));
        expect(rect.center.dx, closeTo(login.center.dx, .01));
        expect(find.byKey(const ValueKey('auth-email-signup')), findsNothing);
        for (final key in [
          'auth-google',
          'auth-email',
          'auth-password',
          if (create) 'auth-confirm-password',
          'account-submit',
          if (!create) 'auth-guest',
        ]) {
          final field = tester.getRect(find.byKey(ValueKey(key)));
          expect(rect.contains(field.topLeft), isTrue, reason: key);
          expect(rect.contains(field.bottomRight), isTrue, reason: key);
        }
        await _tap(tester, find.byKey(const ValueKey('account-submit')));
        expect(find.byType(SingleChildScrollView), findsNothing);
        final submit = tester.getRect(
          find.byKey(const ValueKey('account-submit')),
        );
        expect(rect.contains(submit.bottomRight), isTrue);
        await tester.drag(card, const Offset(-100, -200));
        await tester.pumpAndSettle();
        expect(tester.getRect(card), rect);
      }
    });
  }

  testWidgets(
    'the whole mobile card travels over fixed art with no internal scroll',
    (tester) async {
      final controller = _Controller();
      addTearDown(controller.dispose);
      await _open(
        tester,
        controller,
        size: const Size(320, 568),
        create: true,
        textScale: 2,
      );
      final header = find.byKey(const ValueKey('auth-fixed-header'));
      final card = find.byKey(const ValueKey('auth-form-card'));
      final headerBefore = tester.getRect(header),
          cardBefore = tester.getRect(card);
      final fieldBefore = tester.getRect(
        find.byKey(const ValueKey('auth-google')),
      );
      expect(
        find.descendant(of: card, matching: find.byType(SingleChildScrollView)),
        findsNothing,
      );
      final scroll = tester.widget<SingleChildScrollView>(
        find.byKey(const ValueKey('auth-sheet-travel')),
      );
      expect(scroll.controller!.position.maxScrollExtent, greaterThan(0));
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(Scrollbar), findsNothing);
      await tester.dragFrom(const Offset(160, 300), const Offset(0, -220));
      await tester.pumpAndSettle();
      expect(scroll.controller!.offset, greaterThan(0));
      expect(tester.getRect(header), headerBefore);
      final delta = tester.getRect(card).top - cardBefore.top;
      expect(delta, lessThan(0));
      expect(
        tester.getRect(find.byKey(const ValueKey('auth-google'))).top -
            fieldBefore.top,
        closeTo(delta, .01),
      );
      scroll.controller!.jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.getRect(card), cardBefore);
      await tester.ensureVisible(
        find.byKey(const ValueKey('auth-mode-switch')),
      );
      expect(
        tester
            .getRect(card)
            .contains(
              tester.getCenter(find.byKey(const ValueKey('auth-mode-switch'))),
            ),
        isTrue,
      );
    },
  );

  testWidgets(
    'keyboard lifts the whole card and closing restores its position',
    (tester) async {
      final controller = _Controller();
      addTearDown(controller.dispose);
      await _open(tester, controller, size: const Size(426, 923), create: true);
      final card = find.byKey(const ValueKey('auth-form-card'));
      final header = find.byKey(const ValueKey('auth-fixed-header'));
      final before = tester.getRect(card), art = tester.getRect(header);
      await tester.tap(find.byKey(const ValueKey('auth-email')));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.getRect(card).top, lessThan(before.top));
      expect(tester.getRect(header), art);
      expect(
        tester.getRect(find.byKey(const ValueKey('auth-email'))).bottom,
        lessThanOrEqualTo(643),
      );
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(tester.getRect(card).top, closeTo(before.top, .01));
    },
  );

  testWidgets('iPad rotation keeps form input and the whole-card drag handle', (
    tester,
  ) async {
    final controller = _Controller();
    addTearDown(controller.dispose);
    await _open(tester, controller, size: const Size(768, 1024), create: true);
    await _fill(tester, 'auth-name', 'Synthetic Scanner');
    await _fill(tester, 'auth-email', 'synthetic@example.invalid');
    final card = find.byKey(const ValueKey('auth-form-card'));
    final handle = find.byKey(const ValueKey('auth-sheet-handle'));
    expect(tester.getRect(card).width, 768);
    expect(handle, findsOneWidget);
    tester.view.physicalSize = const Size(1024, 768);
    await tester.pumpAndSettle();
    expect(handle, findsNothing);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.getRect(card).center.dx, closeTo(1024 * .7775, 1));
    tester.view.physicalSize = const Size(768, 1024);
    await tester.pumpAndSettle();
    expect(handle, findsOneWidget);
    expect(tester.getRect(card).width, 768);
    expect(_input(tester, 'auth-name').controller!.text, 'Synthetic Scanner');
    expect(
      _input(tester, 'auth-email').controller!.text,
      'synthetic@example.invalid',
    );
    expect(tester.takeException(), isNull);
  });

  for (final fromProfile in [true, false]) {
    testWidgets('back navigation retains origin $fromProfile across modes', (
      tester,
    ) async {
      final controller = _Controller();
      addTearDown(controller.dispose);
      await _open(tester, controller, fromProfile: fromProfile);
      expect(
        find.byKey(const ValueKey('auth-close')),
        fromProfile ? findsOneWidget : findsNothing,
      );
      await _tap(tester, find.byKey(const ValueKey('auth-mode-switch')));
      expect(
        find.byKey(const ValueKey('auth-close')),
        fromProfile ? findsOneWidget : findsNothing,
      );
      if (fromProfile) {
        await _tap(tester, find.byKey(const ValueKey('auth-close')));
        expect(find.text('Open account'), findsOneWidget);
      }
      expect(controller.signIns + controller.creates + controller.google, 0);
    });
  }

  testWidgets('sign-in accepts legacy password and locks pending operations', (
    tester,
  ) async {
    final controller = _Controller()..operation = Completer<void>();
    addTearDown(controller.dispose);
    await _open(tester, controller);
    await _fill(tester, 'auth-email', ' synthetic@example.invalid ');
    await _fill(tester, 'auth-password', 'short');
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
    expect(
      tester.widget<AuthScene>(find.byType(AuthScene)).celebrating,
      isFalse,
    );
    controller.operation!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Open account'), findsOneWidget);
  });

  testWidgets(
    'signup validates full name, policy and confirmation before one request',
    (tester) async {
      final controller = _Controller();
      addTearDown(controller.dispose);
      await _open(tester, controller, create: true);
      expect(find.byKey(const ValueKey('auth-email-signup')), findsNothing);
      await _fill(tester, 'auth-name', ' Synthetic Scanner ');
      await _fill(tester, 'auth-email', 'synthetic@example.invalid');
      await _fill(tester, 'auth-password', 'password123');
      await _fill(tester, 'auth-confirm-password', 'password123');
      await _tap(tester, find.byKey(const ValueKey('account-submit')));
      expect(controller.creates, 0);
      expect(find.text('Choose a less common password.'), findsOneWidget);
      await _fill(tester, 'auth-password', 'UniqueField42');
      await _tap(tester, find.byKey(const ValueKey('account-submit')));
      expect(controller.creates, 0);
      expect(find.text('Passwords do not match.'), findsOneWidget);
      await _fill(tester, 'auth-confirm-password', 'UniqueField42');
      await _tap(tester, find.byKey(const ValueKey('account-submit')));
      expect(controller.creates, 1);
      expect(controller.name, 'Synthetic Scanner');
      expect(find.text('Open account'), findsOneWidget);
    },
  );

  testWidgets(
    'password indicators and independent visibility follow typed input',
    (tester) async {
      final controller = _Controller();
      addTearDown(controller.dispose);
      await _open(tester, controller, create: true);
      await _fill(tester, 'auth-password', 'UniqueField42');
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
      await _tap(tester, find.byTooltip('Show password'));
      expect(_input(tester, 'auth-password').obscureText, isFalse);
      expect(_input(tester, 'auth-confirm-password').obscureText, isTrue);
      await _fill(tester, 'auth-password', 'UniqueField42!');
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(3));
      await _tap(tester, find.byKey(const ValueKey('auth-mode-switch')));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('auth-password')))
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  testWidgets('cancelled Google sign-in keeps a safe error and guest exit', (
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
    expect(
      tester.widget<AuthScene>(find.byType(AuthScene)).celebrating,
      isFalse,
    );
    await _tap(tester, find.byKey(const ValueKey('auth-guest')));
    expect(find.text('Open account'), findsOneWidget);
  });

  testWidgets('terms and privacy links open readable existing policy', (
    tester,
  ) async {
    final controller = _Controller();
    addTearDown(controller.dispose);
    await _open(tester, controller, create: true);
    await _tap(tester, find.text('Privacy Policy'));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.textContaining(
        'Guest history and saved products stay on this device.',
      ),
      findsOneWidget,
    );
    await _tap(tester, find.text('Close'));
    await _tap(tester, find.text('Terms of Service'));
    expect(find.text('Using Unlabel'), findsOneWidget);
    expect(find.textContaining('an account is optional.'), findsOneWidget);
  });

  testWidgets('reset errors never show sent and success remains neutral', (
    tester,
  ) async {
    final controller = _Controller()
      ..failure = const AppFailure('network', 'Could not connect.');
    addTearDown(controller.dispose);
    await _open(tester, controller);
    await _accountAction(tester, 'auth-forgot', 'Forgot password?');
    await _fill(tester, 'auth-email', 'synthetic@example.invalid');
    await _tap(tester, find.byKey(const ValueKey('account-submit')));
    expect(find.text('Reset link sent!'), findsNothing);
    expect(find.text('Could not connect.'), findsOneWidget);
    controller.failure = null;
    await _tap(tester, find.byKey(const ValueKey('account-submit')));
    expect(controller.resets, 2);
    expect(controller.signIns + controller.creates, 0);
    expect(find.textContaining('If this email has an account'), findsOneWidget);
    expect(
      find.text('Choose a password on Firebase’s secure page'),
      findsOneWidget,
    );
    expect(find.byType(TextFormField), findsNothing);
    await _tap(tester, find.widgetWithText(FilledButton, 'Back to sign in'));
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('auth-email')))
          .controller!
          .text,
      'synthetic@example.invalid',
    );
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'keyboard can scroll every signup field and cannot skip validation text $scale',
      (tester) async {
        final controller = _Controller();
        addTearDown(controller.dispose);
        await _open(
          tester,
          controller,
          size: const Size(320, 568),
          textScale: scale,
          create: true,
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await _tap(tester, find.byKey(const ValueKey('account-submit')));
        expect(controller.creates, 0);
        expect(find.text('Enter your name.'), findsOneWidget);
        for (final field in [
          ('auth-name', 'Synthetic Scanner'),
          ('auth-email', 'synthetic@example.invalid'),
          ('auth-password', 'UniqueField42'),
          ('auth-confirm-password', 'UniqueField42'),
        ]) {
          await _fill(tester, field.$1, field.$2);
          await tester.pumpAndSettle();
          final rect = tester.getRect(find.byKey(ValueKey(field.$1)));
          expect(rect.bottom, lessThanOrEqualTo(308));
        }
        await _tap(tester, find.byKey(const ValueKey('account-submit')));
        expect(controller.creates, 1);
      },
    );
  }

  testWidgets(
    'only completed authentication celebrates and reduced motion stops tickers',
    (tester) async {
      final controller = _Controller()..operation = Completer<void>();
      addTearDown(controller.dispose);
      await _open(tester, controller, reducedMotion: false);
      await tester.ensureVisible(find.byKey(const ValueKey('auth-google')));
      await tester.tap(find.byKey(const ValueKey('auth-google')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<AuthScene>(find.byType(AuthScene)).celebrating,
        isFalse,
      );
      controller.operation!.complete();
      await tester.pump();
      expect(
        tester.widget<AuthScene>(find.byType(AuthScene)).celebrating,
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Open account'), findsOneWidget);
      await _open(tester, controller);
      expect(tester.hasRunningAnimations, isFalse);
    },
  );

  testWidgets('late completion cannot touch a disposed form', (tester) async {
    final controller = _Controller()..operation = Completer<void>();
    addTearDown(controller.dispose);
    await _open(tester, controller);
    await _fill(tester, 'auth-email', 'synthetic@example.invalid');
    await _fill(tester, 'auth-password', 'UniqueField42');
    await tester.ensureVisible(find.byKey(const ValueKey('account-submit')));
    await tester.tap(find.byKey(const ValueKey('account-submit')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    controller.operation!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
