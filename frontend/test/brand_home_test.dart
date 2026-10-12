import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/core/widgets/brand_mark.dart';

void main() {
  testWidgets('brand Home has an accessible name and keyboard activation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var visits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrandHomeButton(
            onPressed: () => visits++,
            child: const Text('Unlabel'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Unlabel Home'), findsOneWidget);
    expect(
      tester.getSize(find.byType(BrandHomeButton)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(visits, 1);
    semantics.dispose();
  });
}
