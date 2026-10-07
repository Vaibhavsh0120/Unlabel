import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/unlabel_repository.dart';
import 'ui_components.dart';

/// Manual barcode fallback within Scan Label. It sends only the printed digits.
class BarcodeEntrySheet extends StatefulWidget {
  const BarcodeEntrySheet({
    required this.repository,
    required this.onOpenReport,
    required this.onEnterLabel,
    super.key,
  });

  final UnlabelRepository repository;
  final Future<void> Function(ProductReport) onOpenReport;
  final VoidCallback onEnterLabel;

  @override
  State<BarcodeEntrySheet> createState() => _BarcodeEntrySheetState();
}

class _BarcodeEntrySheetState extends State<BarcodeEntrySheet> {
  final _form = GlobalKey<FormState>();
  final _input = TextEditingController();
  bool _busy = false;
  String? _error, _errorKind;
  int _request = 0;

  bool _active(int request) =>
      mounted &&
      request == _request &&
      (ModalRoute.of(context)?.isCurrent ?? true);

  @override
  void dispose() {
    _request++;
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final barcode = _input.text.trim();
    final request = ++_request;
    setState(() {
      _busy = true;
      _error = null;
      _errorKind = null;
    });
    ProductReport report;
    try {
      report = await widget.repository.loadReport(barcode);
    } on AppFailure catch (error) {
      if (_active(request)) {
        setState(() {
          _error = error.userMessage;
          _errorKind = error.kind;
        });
      }
      return;
    } catch (_) {
      if (_active(request)) {
        setState(() {
          _error = 'The product could not be opened. Try again or enter the package label.';
          _errorKind = 'unavailable';
        });
      }
      return;
    } finally {
      if (_active(request)) setState(() => _busy = false);
    }
    if (!mounted || !_active(request)) return;
    _request++;
    Navigator.of(context).pop();
    await widget.onOpenReport(report);
  }

  void _enterLabel() {
    if (_busy) return;
    _request++;
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
    widget.onEnterLabel();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Enter barcode',
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close barcode entry',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Type the digits printed below the package barcode.',
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          key: const Key('barcode-input'),
                          controller: _input,
                          autofocus: true,
                          enabled: !_busy,
                          maxLength: 14,
                          maxLengthEnforcement: MaxLengthEnforcement.none,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.search,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(
                            labelText: 'Printed barcode',
                            hintText: '8, 12, 13 or 14 digits',
                          ),
                          validator: (value) =>
                              RegExp(r'^(?:[0-9]{8}|[0-9]{12,14})$')
                                  .hasMatch((value ?? '').trim())
                              ? null
                              : 'Enter an 8, 12, 13 or 14 digit barcode.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          key: const Key('barcode-submit'),
                          onPressed: _busy ? null : _submit,
                          icon: FeatureIcon(
                            'barcode',
                            color: theme.colorScheme.onPrimary,
                            size: 22,
                          ),
                          label: Text(
                            _busy ? 'Looking up…' : 'Look up barcode',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 24),
                    StatusNotice(
                      key: const Key('barcode-error'),
                      title: _errorKind == 'not_found'
                          ? 'No catalogue report for this code'
                          : 'Lookup could not be completed',
                      message: _error!,
                      action: _errorKind == 'not_found'
                          ? OutlinedButton(
                              onPressed: _enterLabel,
                              child: const Text('Enter this package label'),
                            )
                          : OutlinedButton(
                              onPressed: _busy ? null : _submit,
                              child: const Text('Retry lookup'),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
