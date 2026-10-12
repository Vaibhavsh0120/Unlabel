import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/interaction/ui_feedback.dart';
import 'package:unlabel/core/models/app_failure.dart';
import 'package:unlabel/core/models/product_report.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/scanner/presentation/report_page.dart';
import 'package:unlabel/features/scanner/presentation/ui_components.dart';

const _artwork = CornerArtwork(
  asset: 'assets/artwork/history-empty.webp',
  height: 180,
);

Widget _artApp(Widget child, {bool reducedMotion = false}) => MaterialApp(
  builder: (context, content) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
    child: content!,
  ),
  home: Scaffold(body: child),
);

class _Preferences implements PreferencesAdapter {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

class _PendingSaveStore extends LocalStore {
  _PendingSaveStore() : super(preferences: _Preferences());
  final completion = Completer<void>();
  @override
  Future<void> save(ProductReport report) async {
    await completion.future;
    await super.save(report);
  }
}

class _FailingSaveStore extends LocalStore {
  _FailingSaveStore() : super(preferences: _Preferences());
  @override
  Future<void> save(ProductReport report) async =>
      throw const AppFailure('local_storage', 'Synthetic persistence failure');
}

ProductReport _report() => ProductReport.fromJson(
  jsonDecode(
    File('../contracts/examples/label-report-v1.current.synthetic.json')
        .readAsStringSync(),
  ) as JsonMap,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reduced motion keeps artwork static and controls actionable', (
    tester,
  ) async {
    var actions = 0;
    await tester.pumpWidget(
      _artApp(
        Stack(
          children: [
            TextButton(
              onPressed: () => actions++,
              child: const Text('Explore food'),
            ),
            _artwork,
          ],
        ),
        reducedMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.tap(find.text('Explore food'));
    await tester.pumpAndSettle();
    expect(actions, 1);
    await tester.pump(const Duration(seconds: 6));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('artwork pauses in background and resumes in foreground', (
    tester,
  ) async {
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    await tester.pumpWidget(_artApp(_artwork));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('offscreen artwork stops ticking and restarts when visible', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      _artApp(
        SingleChildScrollView(
          controller: scroll,
          child: const Column(children: [_artwork, SizedBox(height: 1800)]),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    scroll.jumpTo(1000);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    scroll.jumpTo(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('artwork holds its pose while scrolling and resumes at idle', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      _artApp(
        SingleChildScrollView(
          controller: scroll,
          child: const Column(children: [_artwork, SizedBox(height: 1800)]),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final artworkTransform = find
        .descendant(
          of: find.byType(CornerArtwork),
          matching: find.byType(Transform),
        )
        .first;
    double pose() =>
        tester.widget<Transform>(artworkTransform).transform.getTranslation().y;
    final before = pose();
    unawaited(
      scroll.animateTo(
        80,
        duration: const Duration(seconds: 1),
        curve: Curves.linear,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(scroll.position.isScrollingNotifier.value, isTrue);
    expect(scroll.offset, greaterThan(0));
    expect(pose(), before);
    await tester.pump(const Duration(milliseconds: 850));
    await tester.pump();
    expect(scroll.position.isScrollingNotifier.value, isFalse);
    await tester.pump(const Duration(milliseconds: 200));
    expect(pose(), isNot(before));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'scrolling to offscreen artwork keeps it idle after scroll ends',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        _artApp(
          SingleChildScrollView(
            controller: scroll,
            child: const Column(children: [_artwork, SizedBox(height: 1800)]),
          ),
        ),
      );
      await tester.pump();
      unawaited(
        scroll.animateTo(
          1000,
          duration: const Duration(milliseconds: 200),
          curve: Curves.linear,
        ),
      );
      await tester.pumpAndSettle();
      expect(scroll.position.isScrollingNotifier.value, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
      scroll.jumpTo(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('confirmed save feedback waits for durable success', (
    tester,
  ) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final store = _PendingSaveStore();
    final report = _report();
    await tester.pumpWidget(
      MaterialApp(
        theme: UnlabelTheme.forBrightness(Brightness.light),
        home: ReportPage(report: report, store: store, onChanged: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-report')));
    await tester.pump();
    expect(haptics, isEmpty);
    expect(await store.saved(), isEmpty);
    store.completion.complete();
    await tester.pumpAndSettle();
    expect((await store.saved()).single.report.id, report.id);
    expect(haptics, ['HapticFeedbackType.lightImpact']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed save never signals confirmed feedback', (tester) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final store = _FailingSaveStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: UnlabelTheme.forBrightness(Brightness.light),
        home: ReportPage(report: _report(), store: store, onChanged: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-report')));
    await tester.pumpAndSettle();
    expect(haptics, isEmpty);
    expect(await store.saved(), isEmpty);
    expect(find.text('Save on this device'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsupported feedback never prevents the user action', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => throw MissingPluginException(),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await expectLater(UiFeedback.selection(), completes);
    await expectLater(UiFeedback.confirmed(), completes);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => throw PlatformException(code: 'unsupported'),
    );
    await expectLater(UiFeedback.selection(), completes);
    await expectLater(UiFeedback.confirmed(), completes);
  });
}
