import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/features/scanner/presentation/startup_page.dart';
import 'package:unlabel/features/scanner/presentation/welcome_page.dart';

Widget _welcome({VoidCallback? onContinue, VoidCallback? onSignIn}) =>
    MaterialApp(
      theme: UnlabelTheme.forBrightness(Brightness.light),
      home: WelcomePage(
        onContinue: onContinue ?? () {},
        onSignIn: onSignIn ?? () {},
      ),
    );

void main() {
  testWidgets('mobile welcome keeps guest and account actions separate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var guestStarts = 0;
    var signIns = 0;
    await tester.pumpWidget(
      _welcome(onContinue: () => guestStarts++, onSignIn: () => signIns++),
    );
    await tester.pumpAndSettle();
    for (final copy in const [
      'Unlabel',
      'Know Beyond the Label',
      'Scan food smarter',
      'Simple insights from every label.',
      'Scan labels',
      'Compare products',
      'Easy insights',
    ]) {
      expect(find.text(copy), findsOneWidget);
    }
    await tester.ensureVisible(find.byKey(const Key('welcome-continue')));
    await tester.tap(find.byKey(const Key('welcome-continue')));
    expect(guestStarts, 1);
    expect(signIns, 0);
    await tester.ensureVisible(find.byKey(const Key('welcome-sign-in')));
    await tester.tap(find.byKey(const Key('welcome-sign-in')));
    expect(guestStarts, 1);
    expect(signIns, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop welcome places copy left and package right', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_welcome());
    await tester.pumpAndSettle();
    final headline = tester.getRect(find.byKey(const Key('welcome-headline')));
    final hero = tester.getRect(
      find.byKey(const Key('welcome-package-artwork')),
    );
    expect(headline.right, lessThan(hero.left));
    expect(
      find.byKey(const Key('welcome-continue')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('welcome-sign-in')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('short narrow welcome keeps both actions reachable at 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_welcome());
    await tester.pumpAndSettle();
    for (final key in const ['welcome-continue', 'welcome-sign-in']) {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      expect(find.byKey(Key(key)).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('startup shows brand and announces genuine app loading', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(home: StartupPage()));
    await tester.pumpAndSettle();
    expect(find.text('Unlabel'), findsOneWidget);
    expect(find.text('Know Beyond the Label'), findsOneWidget);
    expect(find.bySemanticsLabel('Loading Unlabel'), findsOneWidget);
    expect(find.byKey(const Key('startup-loading-dots')), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
