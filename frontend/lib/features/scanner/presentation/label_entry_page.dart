import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/capture/label_text_suggestions.dart';
import '../../../core/capture/local_ocr.dart';
import '../../../core/network/unlabel_repository.dart';

class LabelEntryPage extends StatefulWidget {
  const LabelEntryPage({
    super.key,
    required this.repository,
    required this.onReport,
    this.capturePhotos = const {},
    this.ocrReader,
  });
  final UnlabelRepository repository;
  final void Function(ProductReport) onReport;

  /// Session-only reference photos. Never included in the report payload/storage.
  final Map<int, Uint8List> capturePhotos;
  final LocalOcrReader? ocrReader;
  @override
  State<LabelEntryPage> createState() => _LabelEntryPageState();
}

class _RowInput {
  _RowInput(this.name) : unit = name == 'energy' ? 'kcal' : 'g';
  String name;
  String unit;
  final value = TextEditingController();
}

class _SectionInput {
  String status = 'not_captured';
  bool complete = false;
  final text = TextEditingController();
  DraftSection get draft =>
      DraftSection(status: status, text: text.text, complete: complete);
}

class _LabelEntryPageState extends State<LabelEntryPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _variant = TextEditingController();
  final _quantity = TextEditingController();
  final _barcode = TextEditingController();
  final _claims = TextEditingController();
  final _amount = TextEditingController();
  final _ingredients = _SectionInput();
  final _contains = _SectionInput();
  final _mayContain = _SectionInput();
  final _rows = <_RowInput>[];
  final _errorAnchor = GlobalKey();
  late final _ocrReader = widget.ocrReader ?? LocalOcrReader();
  final _recognizedText = {
    0: TextEditingController(),
    1: TextEditingController(),
  };
  bool _reading = false, _ocrUsed = false;
  double? _readingProgress;
  String? _readingError, _suggestionNotice;
  int _readingGeneration = 0;
  String _language = 'en';
  String _basisKind = 'quantity';
  String _basisUnit = 'g';
  String _preparation = 'as_sold';
  String _category = 'unknown';
  String _foodForm = 'unknown';
  bool _nutritionComplete = false;
  bool _frontConfirmed = false;
  bool _backConfirmed = false;
  bool _sameConfirmed = false;
  bool _busy = false;
  bool _attempted = false;
  bool _dirty = false;
  String? _error;
  String? _submissionId;
  final _observedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.capturePhotos.keys.any((slot) => slot == 0 || slot == 1)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _readPhotos();
      });
    }
  }

  Future<void> _readPhotos() async {
    if (_reading || _busy) return;
    final generation = ++_readingGeneration;
    final language = _language;
    setState(() {
      _reading = true;
      _readingError = null;
      _readingProgress = null;
      _suggestionNotice = null;
    });
    final failures = <String>[];
    for (final slot in [0, 1]) {
      final bytes = widget.capturePhotos[slot];
      if (bytes == null) continue;
      if (!mounted || generation != _readingGeneration) return;
      try {
        final text = await _ocrReader.recognize(
          bytes,
          language: language,
          onProgress: (value) {
            if (mounted && generation == _readingGeneration) {
              setState(() => _readingProgress = value);
            }
          },
        );
        if (!mounted || generation != _readingGeneration) return;
        setState(() {
          _recognizedText[slot]!.text = text;
          if (text.isEmpty) {
            failures.add(
              '${slot == 0 ? 'Front' : 'Back'} photo: no clear text found.',
            );
          }
        });
      } on LocalOcrFailure catch (failure) {
        failures.add(failure.message);
      }
    }
    if (mounted && generation == _readingGeneration) {
      setState(() {
        _reading = false;
        _readingProgress = null;
        _readingError = failures.isEmpty ? null : failures.toSet().join(' ');
      });
    }
  }

  void _stopReading() {
    _readingGeneration++;
    _ocrReader.cancel();
    setState(() {
      _reading = false;
      _readingProgress = null;
      _readingError = null;
    });
  }

  void _applySuggestions() {
    if (_reading || _busy) return;
    final suggestions = LabelTextSuggestions.fromText(
      _recognizedText[0]!.text,
      _recognizedText[1]!.text,
    );
    var changed = false;
    void applySection(_SectionInput target, String? value) {
      if (value != null &&
          target.status == 'not_captured' &&
          target.text.text.isEmpty) {
        target.status = 'present';
        target.text.text = value;
        target.complete = false;
        changed = true;
      }
    }

    setState(() {
      if (suggestions.name != null && _name.text.trim().isEmpty) {
        _name.text = suggestions.name!;
        changed = true;
      }
      applySection(_ingredients, suggestions.ingredients);
      applySection(_contains, suggestions.contains);
      applySection(_mayContain, suggestions.mayContain);
      if (changed) {
        _ocrUsed = true;
        _changed();
      }
      _suggestionNotice = changed
          ? 'Text suggestions added. Check each field against your photo.'
          : 'No new suggestions found. Enter the printed facts in the fields below.';
    });
  }

  void _changed({bool resetConfirmations = true}) {
    _submissionId = null;
    _dirty = true;
    if (resetConfirmations) {
      _frontConfirmed = false;
      _backConfirmed = false;
      _sameConfirmed = false;
    }
  }

  @override
  void dispose() {
    _readingGeneration++;
    if (widget.ocrReader == null) {
      _ocrReader.dispose();
    } else {
      _ocrReader.cancel();
    }
    for (final controller in [
      _name,
      _brand,
      _variant,
      _quantity,
      _barcode,
      _claims,
      _amount,
      _ingredients.text,
      _contains.text,
      _mayContain.text,
      ..._rows.map((row) => row.value),
      ..._recognizedText.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _numeric(
    String? text, {
    bool required = false,
    bool positive = false,
  }) {
    final value = (text ?? '').trim();
    if (value.isEmpty) return required ? 'Enter the printed amount.' : null;
    final number = double.tryParse(value);
    if (number == null ||
        !number.isFinite ||
        number < 0 ||
        (positive && number <= 0) ||
        number > (positive ? 100000 : 1000000)) {
      return positive
          ? 'Use a positive printed amount.'
          : 'Use a nonnegative printed number, or leave empty.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _attempted = true;
      _error = null;
    });
    if (!_form.currentState!.validate()) {
      setState(
        () =>
            _error = 'Check the highlighted fields and package confirmations.',
      );
      _showError();
      return;
    }
    try {
      _submissionId ??= newSubmissionId();
      final amountText = _amount.text.trim();
      final draft = LabelDraft(
        name: _name.text,
        brand: _brand.text,
        variant: _variant.text,
        quantity: _quantity.text,
        barcode: _barcode.text,
        language: _language,
        ingredients: _ingredients.draft,
        contains: _contains.draft,
        mayContain: _mayContain.draft,
        claims: _claims.text
            .split(RegExp(r'[\r\n]+'))
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
        rows: [
          for (final row in _rows)
            DraftNutrient(
              name: row.name,
              value: row.value.text.trim().isEmpty
                  ? null
                  : double.parse(row.value.text.trim()),
              unit: row.unit,
            ),
        ],
        basis: DraftBasis(
          kind: _basisKind,
          amount: amountText.isEmpty ? null : double.parse(amountText),
          unit: amountText.isEmpty ? null : _basisUnit,
        ),
        preparation: _preparation,
        nutritionComplete: _nutritionComplete,
        foodCategory: _category,
        foodForm: _foodForm,
        frontConfirmed: _frontConfirmed,
        backConfirmed: _backConfirmed,
        samePackageConfirmed: _sameConfirmed,
        captureMethod: _ocrUsed ? 'ocr_corrected' : 'manual',
        submissionId: _submissionId,
        observedAt: _observedAt,
      );
      draft.toPayload();
      _readingGeneration++;
      _ocrReader.cancel();
      setState(() {
        _busy = true;
        _reading = false;
        _readingProgress = null;
      });
      final report = await widget.repository.checkLabel(draft);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _dirty = false;
      });
      // Allow PopScope to rebuild before the parent's navigation callback.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onReport(report);
      });
    } on AppFailure catch (failure) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = failure.userMessage;
        });
        _showError();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'The label could not be checked. Your entries are kept; please try again.';
        });
        _showError();
      }
    }
  }

  void _showError() => WidgetsBinding.instance.addPostFrameCallback((_) {
    final anchor = _errorAnchor.currentContext;
    if (anchor != null) {
      Scrollable.ensureVisible(
        anchor,
        duration: const Duration(milliseconds: 180),
      );
    }
  });

  Future<void> _back(bool didPop) async {
    if (didPop || _busy || !_dirty) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this label?'),
        content: const Text('The unsubmitted entries are only on this page.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard entries'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _dirty = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope<void>(
      canPop: !_dirty && !_busy,
      onPopInvokedWithResult: (didPop, _) => _back(didPop),
      child: Scaffold(
        appBar: AppBar(title: const Text('Enter package label')),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Form(
                  key: _form,
                  autovalidateMode: _attempted
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Read it from your package',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter the front identity and corrected back-label facts. Empty or uncaptured fields stay unknown. Enter only what you can read on this package.',
                      ),
                      const SizedBox(height: 20),
                      if (widget.capturePhotos.isNotEmpty) ...[
                        _card('Your captured label', [
                          const Text(
                            'Text reading happens on this device. Check suggestions against your photo before confirming the facts.',
                          ),
                          for (final photo in widget.capturePhotos.entries) ...[
                            const SizedBox(height: 12),
                            Text(photo.key == 0 ? 'Front label' : 'Back label'),
                            SizedBox(
                              height: 260,
                              child: InteractiveViewer(
                                child: Image.memory(
                                  photo.value,
                                  fit: BoxFit.contain,
                                  semanticLabel: photo.key == 0
                                      ? 'Your front label photo'
                                      : 'Your back label photo',
                                  errorBuilder: (_, _, _) => const Text(
                                    'This photo cannot be displayed. Retake it or enter the label manually.',
                                  ),
                                ),
                              ),
                            ),
                          ],
                          _select('Text reading language', _language, const {
                            'en': 'English',
                            'hi': 'Hindi and English',
                          }, (value) => _language = value),
                          if (_reading) ...[
                            const SizedBox(height: 12),
                            LinearProgressIndicator(value: _readingProgress),
                            const SizedBox(height: 8),
                            const Text('Reading your label on this device…'),
                            TextButton(
                              onPressed: _stopReading,
                              child: const Text('Stop reading'),
                            ),
                          ] else
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _readPhotos,
                              icon: const Icon(Icons.text_fields_rounded),
                              label: const Text('Read text on this device'),
                            ),
                          if (_readingError != null)
                            Semantics(
                              liveRegion: true,
                              child: Text(_readingError!),
                            ),
                          for (final slot in [0, 1])
                            if (_recognizedText[slot]!.text.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                key: Key(
                                  'ocr-${slot == 0 ? 'front' : 'back'}-text',
                                ),
                                controller: _recognizedText[slot],
                                enabled: !_busy && !_reading,
                                minLines: 3,
                                maxLines: 7,
                                maxLength: LocalOcrReader.maxText,
                                decoration: InputDecoration(
                                  labelText:
                                      '${slot == 0 ? 'Front' : 'Back'} text suggestions',
                                ),
                              ),
                            ],
                          if (_recognizedText.values.any(
                            (text) => text.text.isNotEmpty,
                          )) ...[
                            const SizedBox(height: 12),
                            FilledButton.tonal(
                              onPressed: _busy || _reading
                                  ? null
                                  : _applySuggestions,
                              child: const Text('Use text suggestions'),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Nutrition values need manual entry from the printed table.',
                            ),
                          ],
                          if (_suggestionNotice != null) ...[
                            const SizedBox(height: 8),
                            Semantics(
                              liveRegion: true,
                              child: Text(_suggestionNotice!),
                            ),
                          ],
                        ]),
                      ],
                      _card('1. Product identity', [
                        _field(
                          _name,
                          'Printed product name',
                          max: 256,
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Enter the printed product name.'
                              : null,
                        ),
                        _field(_brand, 'Brand (if printed)', max: 128),
                        _field(_variant, 'Variant (if printed)', max: 128),
                        _field(
                          _quantity,
                          'Net quantity (if printed)',
                          hint: 'For example, 300 g',
                          max: 128,
                        ),
                        _field(
                          _barcode,
                          'Barcode (optional)',
                          max: 14,
                          keyboard: TextInputType.number,
                          validator: (value) =>
                              (value ?? '').trim().isEmpty ||
                                  RegExp(r'^(?:[0-9]{8}|[0-9]{12,14})$')
                                      .hasMatch(value!.trim())
                              ? null
                              : 'Use 8, 12, 13 or 14 digits.',
                        ),
                        _select('Package text language', _language, const {
                          'en': 'English',
                          'hi': 'Hindi',
                        }, (value) => _language = value),
                      ]),
                      _card('2. Back-package sections', [
                        const Text(
                          'Copy each whole printed section. “Not observed” means you checked the package and did not find that statement; it does not mean allergy-safe.',
                        ),
                        _section('Ingredients', _ingredients),
                        _section('Contains statement', _contains),
                        _section('May contain statement', _mayContain),
                      ]),
                      _card('3. Printed nutrition table', [
                        const Text(
                          'Use one table and its printed basis. Add only rows printed on your label. A blank value in an added row is unknown; a printed zero is 0.',
                        ),
                        if (_rows.isNotEmpty) ...[
                          _select('Table basis', _basisKind, const {
                            'quantity': 'Per printed quantity',
                            'serving': 'Per serving',
                          }, (value) => _basisKind = value),
                          _field(
                            _amount,
                            'Printed basis amount',
                            hint: _basisKind == 'serving'
                                ? 'Leave empty if serving size is unknown'
                                : 'For example, 100',
                            keyboard: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (value) => _numeric(
                              value,
                              required: _basisKind == 'quantity',
                              positive: true,
                            ),
                          ),
                          _select('Basis unit', _basisUnit, const {
                            'g': 'g',
                            'mL': 'mL',
                          }, (value) => _basisUnit = value),
                          _select('Table preparation', _preparation, const {
                            'as_sold': 'As sold',
                            'as_prepared': 'As prepared',
                          }, (value) => _preparation = value),
                          for (final row in _rows) _nutrient(row),
                        ],
                        OutlinedButton.icon(
                          onPressed:
                              _busy ||
                                  _rows.length >= DraftNutrient.names.length
                              ? null
                              : () {
                                  setState(() {
                                    final available = DraftNutrient.names
                                        .where(
                                          (name) => !_rows.any(
                                            (row) => row.name == name,
                                          ),
                                        )
                                        .toList();
                                    _rows.add(
                                      _RowInput(
                                        available.contains('protein')
                                            ? 'protein'
                                            : available.first,
                                      ),
                                    );
                                    _changed();
                                  });
                                },
                          icon: const Icon(Icons.add),
                          label: const Text('Add printed nutrient row'),
                        ),
                        if (_rows.isNotEmpty)
                          _check(
                            'I entered every row in this printed table',
                            _nutritionComplete,
                            (value) => _nutritionComplete = value,
                          ),
                      ]),
                      _card('4. Front claims and confirmation', [
                        _field(
                          _claims,
                          'Exact printed front claims (optional)',
                          hint: 'One claim per line',
                          lines: 3,
                          max: 4112,
                          validator: (value) {
                            final claims = (value ?? '')
                                .split(RegExp(r'[\r\n]+'))
                                .where((text) => text.trim().isNotEmpty)
                                .toList();
                            return claims.length > 16 ||
                                    claims.any(
                                      (text) => text.trim().length > 256,
                                    )
                                ? 'Use up to 16 claims, each up to 256 characters.'
                                : null;
                          },
                        ),
                        _select(
                          'Food category for claim checks',
                          _category,
                          const {
                            'unknown': 'Unknown',
                            'ordinary_general_food': 'Ordinary general food',
                            'special_food': 'Special food',
                          },
                          (value) => _category = value,
                        ),
                        _select(
                          'Product form for claim checks',
                          _foodForm,
                          const {
                            'unknown': 'Unknown',
                            'solid': 'Solid',
                            'liquid': 'Liquid',
                          },
                          (value) => _foodForm = value,
                        ),
                        const Text(
                          'Unknown context keeps claim checks inconclusive. These checks cover reviewed numerical criteria and ingredient functions; they do not produce an overall health score.',
                        ),
                        const SizedBox(height: 12),
                        _confirmation(
                          'I checked the identity and claims on the package front',
                          _frontConfirmed,
                          (value) => _frontConfirmed = value,
                        ),
                        _confirmation(
                          'I checked and corrected the back-label facts I entered',
                          _backConfirmed,
                          (value) => _backConfirmed = value,
                        ),
                        _confirmation(
                          'The front, back and any barcode belong to this same package',
                          _sameConfirmed,
                          (value) => _sameConfirmed = value,
                        ),
                      ]),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Confirmed structured facts are saved automatically. Compatible facts linked to a barcode may join the public catalogue as unreviewed observations under CC0. Without a barcode, facts stay in temporary private staging. Photos and raw OCR are not uploaded by this form.',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_error != null)
                        Padding(
                          key: _errorAnchor,
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                        ),
                      FilledButton.icon(
                        onPressed: _busy ? null : _submit,
                        icon: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.fact_check_outlined),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Check confirmed label'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 20),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    int lines = 1,
    int max = 16000,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: TextFormField(
      controller: controller,
      enabled: !_busy,
      minLines: lines,
      maxLines: lines > 1 ? 8 : 1,
      maxLength: max,
      keyboardType:
          keyboard ??
          (lines > 1 ? TextInputType.multiline : TextInputType.text),
      textInputAction: lines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: true,
        errorMaxLines: 4,
        helperMaxLines: 4,
        counterText: '',
      ),
      validator: validator,
      onChanged: (_) => setState(() => _changed()),
    ),
  );

  Widget _select(
    String label,
    String selected,
    Map<String, String> options,
    void Function(String) update,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: options.entries
          .map(
            (entry) => DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value, softWrap: true),
            ),
          )
          .toList(),
      onChanged: _busy
          ? null
          : (value) {
              if (value != null) {
                setState(() {
                  update(value);
                  _changed();
                });
              }
            },
    ),
  );

  Widget _check(
    String label,
    bool value,
    void Function(bool) update, {
    bool confirmation = false,
  }) => CheckboxListTile(
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    title: Text(label),
    value: value,
    onChanged: _busy
        ? null
        : (value) => setState(() {
            update(value ?? false);
            _changed(resetConfirmations: !confirmation);
          }),
  );

  Widget _confirmation(String label, bool value, void Function(bool) update) =>
      FormField<bool>(
        initialValue: value,
        validator: (_) => value ? null : 'Confirmation is required.',
        builder: (field) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _check(label, value, (next) {
              update(next);
              field.didChange(next);
            }, confirmation: true),
            if (field.hasError)
              Text(
                field.errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      );

  Widget _section(String label, _SectionInput input) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 8),
      _select('$label capture', input.status, const {
        'not_captured': 'Not captured',
        'present': 'Printed text present',
        'not_observed': 'Checked, not observed',
      }, (value) => input.status = value),
      if (input.status == 'present')
        _field(
          input.text,
          'Whole $label text',
          lines: 3,
          validator: (value) => (value ?? '').trim().isEmpty
              ? 'Enter the printed section text.'
              : null,
        ),
      if (input.status != 'not_captured')
        _check(
          'I checked the whole $label section',
          input.complete,
          (value) => input.complete = value,
        ),
    ],
  );

  Widget _nutrient(_RowInput row) {
    final available = DraftNutrient.names.where(
      (name) => name == row.name || !_rows.any((other) => other.name == name),
    );
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _select(
            'Printed nutrient',
            row.name,
            {for (final name in available) name: _nutrientLabel(name)},
            (value) {
              row.name = value;
              row.unit = value == 'energy' ? 'kcal' : 'g';
            },
          ),
          _field(
            row.value,
            '${_nutrientLabel(row.name)} value',
            hint: 'Blank means unknown',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            validator: _numeric,
          ),
          _select(
            'Printed nutrient unit',
            row.unit,
            row.name == 'energy'
                ? const {'kcal': 'kcal', 'kJ': 'kJ'}
                : const {'g': 'g', 'mg': 'mg', 'ug': 'µg'},
            (value) => row.unit = value,
          ),
          TextButton.icon(
            onPressed: _busy
                ? null
                : () {
                    setState(() {
                      _rows.remove(row);
                      _changed();
                    });
                    row.value.dispose();
                  },
            icon: const Icon(Icons.remove_circle_outline),
            label: const Text('Remove row'),
          ),
        ],
      ),
    );
  }

  String _nutrientLabel(String name) =>
      const {
        'energy': 'Energy',
        'fat': 'Total fat',
        'saturated_fat': 'Saturated fat',
        'carbohydrates': 'Available carbohydrates',
        'carbohydrates_total': 'Total carbohydrates',
        'sugars': 'Total sugars',
        'added_sugars': 'Added sugars',
        'fibre': 'Fibre',
        'protein': 'Protein',
        'sodium': 'Sodium',
        'salt': 'Salt',
      }[name] ??
      name;
}
