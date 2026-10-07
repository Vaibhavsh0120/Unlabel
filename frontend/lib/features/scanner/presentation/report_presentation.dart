import '../../../core/models/product_report.dart';

/// Display helpers keep unknown states and source qualification intact.
String reportDeclarationSummary(ReportSection section) =>
    switch (section.status) {
      'present' => section.text ?? 'Unknown',
      'not_observed' => 'No declaration observed',
      'not_captured' => 'Not captured',
      'conflict' => 'Conflicting observations',
      'not_comparable' => 'Different package contexts',
      _ => 'Unknown',
    };

String reportEvidenceLabel(String? value) => switch (value) {
  'user_confirmed_label' => 'Your confirmed label',
  'submitter_confirmed_not_moderator_reviewed' =>
    'Submitter confirmed, unreviewed',
  'moderator_accepted_community_assertion' =>
    'Community assertion with recorded acceptance',
  'open_food_facts_community_observation' =>
    'Open Food Facts community observation',
  null => 'Evidence state unavailable',
  _ => value.replaceAll('_', ' '),
};

/// A photo is rendered only from the canonical provider descriptor. Decorative
/// artwork must not be displayed as a picture of the reported product.
class ReportImageDescriptor {
  const ReportImageDescriptor._({
    required this.url,
    required this.attribution,
    required this.license,
    required this.licenseUrl,
  });

  final String url;
  final String attribution;
  final String license;
  final String licenseUrl;

  static ReportImageDescriptor? fromReport(ProductReport report) {
    Map<String, dynamic> map(Object? value) =>
        value is Map<String, dynamic> ? value : const {};
    final snapshot = map(map(report.raw['resolved'])['off_snapshot']);
    final descriptor = map(map(snapshot['details'])['image']);
    final url = descriptor['url'];
    final language = descriptor['language'];
    final revision = descriptor['revision'];
    if (snapshot['status'] != 'found' ||
        url is! String ||
        url.length > 512 ||
        language is! String ||
        !RegExp(r'^[a-z]{2,3}$').hasMatch(language) ||
        revision is! int ||
        revision < 1 ||
        revision > 2147483647 ||
        descriptor['size'] != 400 ||
        descriptor['provider'] != 'open_food_facts' ||
        descriptor['attribution'] !=
            'Product image from Open Food Facts contributors' ||
        descriptor['license'] != 'CC-BY-SA-3.0' ||
        descriptor['license_url'] !=
            'https://creativecommons.org/licenses/by-sa/3.0/') {
      return null;
    }
    final expected = RegExp(
      r'^https://images\.openfoodfacts\.org/images/products/'
      r'[0-9]{3}/[0-9]{3}/[0-9]{3}/[0-9]{4,5}/'
      r'front_([a-z]{2,3})\.([1-9][0-9]{0,9})\.400\.jpg$',
    ).firstMatch(url);
    if (expected == null ||
        expected.group(1) != language ||
        expected.group(2) != '$revision') {
      return null;
    }
    for (final dimension in ['width', 'height']) {
      final value = descriptor[dimension];
      if (value != null && (value is! int || value < 1 || value > 400)) {
        return null;
      }
    }
    return ReportImageDescriptor._(
      url: url,
      attribution: descriptor['attribution'] as String,
      license: descriptor['license'] as String,
      licenseUrl: descriptor['license_url'] as String,
    );
  }
}
