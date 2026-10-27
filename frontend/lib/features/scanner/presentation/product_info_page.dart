import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/interaction/ui_feedback.dart';
import '../../../core/network/unlabel_repository.dart';
import '../../../core/storage/local_store.dart';
import 'product_results_layout.dart';
import 'report_presentation.dart';
import 'ui_components.dart';

part 'product_info_report.dart';
part 'product_info_research.dart';
part 'product_info_extracted.dart';
part 'product_info_supplements.dart';
part 'product_info_claims.dart';

/// The single product destination for search, scans, history and saved items.
/// Content retains its source's evidence status; opening this page does not
/// promote catalogue or machine-read facts into a confirmed report.
class ProductInfoPage extends StatelessWidget {
  ProductInfoPage.report({
    required ProductReport report,
    required LocalStore store,
    required VoidCallback onChanged,
    Uint8List? sessionPhoto,
    UnlabelRepository? repository,
    List<String> frontClaims = const [],
    this.navigation,
    super.key,
  }) : _content = _ReportContent(
         key: ObjectKey(report),
         report: report,
         store: store,
         onChanged: onChanged,
         sessionPhoto: sessionPhoto,
         repository: repository,
         frontClaims: frontClaims,
       );

  ProductInfoPage.research({
    required ResearchedProduct product,
    UnlabelRepository? repository,
    List<String> frontClaims = const [],
    this.navigation,
    super.key,
  }) : _content = _ResearchContent(
         product: product,
         repository: repository,
         frontClaims: frontClaims,
       );

  ProductInfoPage.barcode({
    required String barcode,
    required UnlabelRepository repository,
    this.navigation,
    super.key,
  }) : _content = ProductResultsLayout(
         main: [
           ResultsIdentityCard(name: 'Scanned product', barcode: barcode),
           const SizedBox(height: 16),
           const StatusNotice(
             title: 'Package details needed',
             message: 'This barcode is not in the local catalogue. Photograph the front and back to read its name, ingredients and nutrition.',
           ),
         ],
         aside: [_ProductSupplements(repository: repository, barcode: barcode)],
       );

  ProductInfoPage.extracted({
    required ExtractedLabel label,
    Uint8List? photo,
    bool localFallback = false,
    UnlabelRepository? repository,
    Future<void> Function(ProductReport)? onOpenReport,
    String? barcode,
    List<ResearchedCandidate> candidates = const [],
    List<SearchCandidate> catalogueCandidates = const [],
    this.navigation,
    super.key,
  }) : _content = _ExtractedContent(
         key: ObjectKey(label),
         label: label,
         photo: photo,
         localFallback: localFallback,
         repository: repository,
         onOpenReport: onOpenReport,
         barcode: barcode,
         candidates: candidates,
         catalogueCandidates: catalogueCandidates,
         navigation: navigation,
       );

  final ResultsNavigation? navigation;
  final Widget _content;

  @override
  Widget build(BuildContext context) => ScaffoldMessenger(
    child: Scaffold(
      appBar: ResultsAppBar(title: 'Product info', navigation: navigation),
      body: _content,
    ),
  );
}
