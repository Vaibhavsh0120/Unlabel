import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/models/product_report.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/scanner/presentation/home_page.dart';
import 'package:unlabel/features/scanner/presentation/library_page.dart';

class _Preferences implements PreferencesAdapter {
  _Preferences(this.entries);
  final List<LocalReport> entries;
  @override
  Future<String?> read(String key) async => key == LocalStore.historyKey
      ? jsonEncode({
          'schema_version': '1',
          'entries': entries.map((entry) => entry.toJson()).toList(),
        })
      : null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> remove(String key) async {}
}

void main() {
  for (final width in [1200.0, 1440.0, 1728.0]) {
    for (final count in [1, 2, 3, 4]) {
      testWidgets(
        'recent $count scans fill available desktop space at $width',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final entries = List.generate(count, (index) {
            final raw = jsonDecode(
              File(
                '../contracts/examples/label-report-v1.current.synthetic.json',
              ).readAsStringSync(),
            ) as JsonMap;
            raw['identity']['name'] = index.isEven
                ? 'Synthetic oats'
                : 'Synthetic longer product name to verify natural card height';
            return LocalReport(
              id: 'layout-$index',
              report: ProductReport.fromJson(raw),
              storedAt: DateTime.utc(2026, 11, 14),
            );
          });
          ProductReport? opened;
          await tester.pumpWidget(
            MaterialApp(
              theme: UnlabelTheme.forBrightness(Brightness.dark),
              home: Scaffold(
                body: Row(
                  children: [
                    const SizedBox(width: 240),
                    Expanded(
                      child: HomePage(
                        store: LocalStore(preferences: _Preferences(entries)),
                        desktop: true,
                        onLookup: (_) {},
                        onEnterLabel: () {},
                        onOpenReport: (report) => opened = report,
                        onLibrary: (_) {},
                        refreshKey: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final visibleCount = count.clamp(1, 3);
          expect(find.byType(StoredProductPhoto), findsNWidgets(visibleCount));
          for (final photo in tester.widgetList<StoredProductPhoto>(
            find.byType(StoredProductPhoto),
          )) {
            expect(photo.size, greaterThanOrEqualTo(100));
          }
          final grid = tester.getRect(
            find.byKey(const Key('desktop-recent-scans')),
          );
          final cards = List.generate(
            visibleCount,
            (index) =>
                tester.getRect(find.byKey(Key('recent-scan-layout-$index'))),
          );
          expect(cards.first.left, closeTo(grid.left, .01));
          for (final card in cards) {
            final row = cards.where(
              (other) => (other.top - card.top).abs() < .01,
            );
            expect(row.last.right, closeTo(grid.right, .01));
            for (final other in row) {
              expect(other.height, closeTo(card.height, .01));
            }
          }
          final last = find.byKey(
            Key('recent-scan-layout-${visibleCount - 1}'),
          );
          await tester.ensureVisible(last);
          await tester.tap(last);
          expect(opened?.raw, equals(entries[visibleCount - 1].report.raw));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
