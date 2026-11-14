import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/accounts/account_auth.dart';
import 'package:unlabel/features/account/presentation/sign_in_methods_view.dart';
import 'package:unlabel/features/scanner/presentation/insights_page.dart';
import 'package:unlabel/features/scanner/domain/insight_controller.dart';
import 'package:unlabel/core/storage/local_store.dart';

class _Preferences implements PreferencesAdapter {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> remove(String key) async {}
}

void main() {
  testWidgets(
    'larger typography preserves narrow insight and provider layouts',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final reporter = FlutterError.onError;
      FlutterError.onError = (details) {
        debugPrint(details.toString());
        reporter?.call(details);
      };
      addTearDown(() => FlutterError.onError = reporter);
      final insights = InsightController(preferences: _Preferences());
      for (final page in [
        InsightsPage(controller: insights),
        SignInMethodsView(
          identity: const AccountIdentity(
            uid: 'test',
            email: 'scanner@example.invalid',
            providers: {'password', 'google.com'},
          ),
          busy: false,
          onClose: () {},
          onGoogle: () {},
          onPassword: () {},
          onDelete: () {},
          onChangeEmail: () {},
          onChangePassword: () {},
          onSwitchGoogle: () {},
        ),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: UnlabelTheme.forBrightness(Brightness.dark),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(page is InsightsPage ? 2 : 1),
              ),
              child: child!,
            ),
            home: Scaffold(body: page),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: page.runtimeType.toString(),
        );
        await tester.pumpWidget(const SizedBox());
      }
      insights.dispose();
    },
  );
}
