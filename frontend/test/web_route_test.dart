import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/app/web_route.dart';
import 'package:unlabel/core/accounts/account_auth.dart';
import 'package:unlabel/core/accounts/account_controller.dart';
import 'package:unlabel/core/accounts/account_data.dart';
import 'package:unlabel/core/accounts/account_sync_api.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/account/presentation/auth_page.dart';

class _NoStorage implements PreferencesAdapter {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> remove(String key) async =>
      throw StateError('A reset action must not delete account storage.');
  @override
  Future<void> write(String key, String value) async =>
      throw StateError('A reset action must not persist its code.');
}

class _NoSync implements AccountSyncTransport {
  @override
  Future<bool> available() async => false;
  @override
  Future<AccountSnapshot> fetch(String token) async =>
      throw StateError('A reset form must not fetch private reports.');
  @override
  Future<AccountSnapshot> put(String token, AccountMutation mutation) async =>
      throw StateError('A reset form must not upload private reports.');
  @override
  void cancelAll() {}
  @override
  void close() {}
}

class _ResetController extends AccountController {
  _ResetController()
    : super(
        auth: UnavailableAccountAuth(),
        api: _NoSync(),
        guestStore: LocalStore(preferences: _NoStorage()),
        preferences: _NoStorage(),
      );

  final verifiedEmail = Completer<String>();
  String? receivedCode;
  @override
  Future<String> verifyPasswordResetCode(String code) {
    receivedCode = code;
    return verifiedEmail.future;
  }

  @override
  void dispose() {
    super.dispose();
    auth.dispose();
  }
}

void main() {
  test('Firebase reset parameters extract the opaque code only', () {
    final uri = Uri.parse(
      'https://unlabel-india.vercel.app/'
      '?mode=resetPassword&oobCode=synthetic-code_123'
      '&apiKey=synthetic-public-api-key&lang=en'
      '&continueUrl=https%3A%2F%2Fexample.invalid%2F',
    );
    expect(passwordResetCodeFromUri(uri), 'synthetic-code_123');
  });

  test(
    'reset codes are decoded once without interpreting URL-like content',
    () {
      final uri = Uri.https('example.invalid', '/', {
        'mode': 'resetPassword',
        'oobCode': 'opaque+code%2F',
      });
      expect(passwordResetCodeFromUri(uri), 'opaque+code%2F');
    },
  );

  test('exact bridge fragment accepts a reset code without a server query', () {
    final uri = Uri.parse(
      'https://unlabel-india.vercel.app/'
      '#/account-reset?mode=resetPassword&oobCode=synthetic-fragment-code',
    );
    expect(uri.query, isEmpty);
    expect(passwordResetCodeFromUri(uri), 'synthetic-fragment-code');
    expect(
      passwordResetCodeFromUri(
        Uri.parse(
          'https://example.invalid/#/account-reset?mode=verifyEmail&oobCode=synthetic-code',
        ),
      ),
      isNull,
    );
    expect(
      passwordResetCodeFromUri(
        Uri.parse(
          'https://example.invalid/#/account-reset?mode=resetPassword&oobCode=${'x' * 2049}',
        ),
      ),
      isNull,
    );
  });

  for (final mode in [
    null,
    '',
    'verifyEmail',
    'recoverEmail',
    'signIn',
    'ResetPassword',
  ]) {
    test('other action mode $mode does not enter a password-reset form', () {
      final uri = Uri.https('example.invalid', '/', {
        'mode': ?mode,
        'oobCode': 'synthetic-code',
      });
      expect(passwordResetCodeFromUri(uri), isNull);
    });
  }

  test('missing, empty and oversized reset codes are rejected', () {
    for (final code in [null, '', 'x' * 2049]) {
      final uri = Uri.https('example.invalid', '/', {
        'mode': 'resetPassword',
        'oobCode': ?code,
      });
      expect(passwordResetCodeFromUri(uri), isNull);
    }
    expect(
      passwordResetCodeFromUri(
        Uri.https('example.invalid', '/', {
          'mode': 'resetPassword',
          'oobCode': 'x' * 2048,
        }),
      )?.length,
      2048,
    );
  });

  test('fragment and unrelated return URLs are not treated as reset codes', () {
    expect(
      passwordResetCodeFromUri(
        Uri.parse(
          'https://example.invalid/#/reset?mode=resetPassword&oobCode=synthetic-code',
        ),
      ),
      isNull,
    );
    expect(
      passwordResetCodeFromUri(
        Uri.https('example.invalid', '/', {
          'continueUrl': 'https://example.invalid/?mode=resetPassword&oobCode=synthetic-code',
        }),
      ),
      isNull,
    );
  });

  testWidgets('reset URL and code stay out of rendered fields and semantics', (
    tester,
  ) async {
    const code = 'synthetic-sensitive-reset-code';
    const apiKey = 'synthetic-public-api-key';
    final uri = Uri.https('example.invalid', '/', {
      'mode': 'resetPassword',
      'oobCode': code,
      'apiKey': apiKey,
    });
    final controller = _ResetController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: UnlabelTheme.forBrightness(Brightness.light),
        home: AuthPage(
          controller: controller,
          fromProfile: false,
          resetCode: passwordResetCodeFromUri(uri),
        ),
      ),
    );
    await tester.pump();
    expect(controller.receivedCode, code);
    expect(find.text('Checking reset link…'), findsOneWidget);
    controller.verifiedEmail.complete('synthetic@example.invalid');
    await tester.pumpAndSettle();
    expect(find.text('Create a new password'), findsOneWidget);
    final text = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
        .join('\n');
    final semantics = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((widget) => widget.properties.label ?? '')
        .join('\n');
    final fields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .map((widget) => widget.controller.text)
        .join('\n');
    for (final rendered in [text, semantics, fields]) {
      expect(rendered, isNot(contains(code)));
      expect(rendered, isNot(contains(apiKey)));
      expect(rendered, isNot(contains(uri.toString())));
    }
    expect(tester.takeException(), isNull);
  });
}
