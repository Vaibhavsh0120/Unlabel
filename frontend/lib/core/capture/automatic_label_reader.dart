import 'dart:async';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import '../network/unlabel_repository.dart';
import 'barcode_reader.dart';
import 'local_label_parser.dart';
import 'local_ocr.dart';
import 'vision_photo.dart';

class AutomaticScanResult {
  const AutomaticScanResult({
    this.barcode,
    this.report,
    this.label,
    this.candidates = const [],
    this.catalogueCandidates = const [],
    this.localFallback = false,
    this.barcodePoints = const [],
    this.barcodeSlot,
    this.capturedSlots = const [],
  });
  final String? barcode;
  final ProductReport? report;
  final ExtractedLabel? label;
  final List<ResearchedCandidate> candidates;
  final List<SearchCandidate> catalogueCandidates;
  final bool localFallback;
  final List<Offset> barcodePoints;
  final int? barcodeSlot;
  final List<int> capturedSlots;
  bool get useful =>
      barcode != null ||
      report != null ||
      candidates.isNotEmpty ||
      catalogueCandidates.isNotEmpty ||
      label?.hasFacts == true;
}

class AutomaticLabelReader {
  AutomaticLabelReader(
    this.repository, {
    BarcodeReader? barcodeReader,
    LocalOcrReader? ocrReader,
  }) : _barcode = barcodeReader ?? BarcodeReader(),
       _ocr = ocrReader ?? LocalOcrReader();
  final UnlabelRepository repository;
  final BarcodeReader _barcode;
  final LocalOcrReader _ocr;
  int _generation = 0;
  bool _disposed = false;
  Completer<void>? _abort;

  Future<AutomaticScanResult> read(
    Map<int, Uint8List> photos, {
    required Future<bool> Function() allowCloud,
  }) async {
    if (_disposed) {
      throw const AppFailure('cancelled', 'Reading stopped.');
    }
    if (_abort != null) cancel();
    final abort = Completer<void>();
    _abort = abort;
    final generation = ++_generation;
    try {
      return await Future.any([
        _read(photos, allowCloud, generation, abort.future),
        abort.future.then<AutomaticScanResult>((_) {
          throw const AppFailure('cancelled', 'Reading stopped.');
        }),
      ]);
    } finally {
      if (identical(_abort, abort)) _abort = null;
      if (!abort.isCompleted) abort.complete();
    }
  }

  Future<AutomaticScanResult> _read(
    Map<int, Uint8List> photos,
    Future<bool> Function() allowCloud,
    int generation,
    Future<void> abortTrigger,
  ) async {
    void current() {
      if (_disposed || generation != _generation) {
        throw const AppFailure('cancelled', 'Reading stopped.');
      }
    }

    String? detected;
    BarcodeDetection? detection;
    int? barcodeSlot;
    for (final photo in photos.entries.toList().reversed) {
      detection = await _barcode.read(photo.value);
      detected = detection?.code;
      current();
      if (detected != null) {
        barcodeSlot = photo.key;
        break;
      }
    }
    // Front/back capture explicitly requests a fresh label reading, even when
    // a barcode happens to be visible in that photo.
    if (detected != null && photos.keys.every((slot) => slot == 2)) {
      try {
        final report = await repository.loadReport(detected);
        current();
        return AutomaticScanResult(
          barcode: detected,
          report: report,
          barcodePoints: detection!.points,
          barcodeSlot: barcodeSlot,
        );
      } on AppFailure catch (failure) {
        if (failure.kind == 'cancelled') rethrow;
      }
      try {
        final candidates = await repository.researchByBarcode(detected);
        current();
        if (candidates.isNotEmpty) {
          return AutomaticScanResult(
            barcode: detected,
            candidates: candidates,
            barcodePoints: detection!.points,
            barcodeSlot: barcodeSlot,
          );
        }
      } on AppFailure catch (failure) {
        if (failure.kind == 'cancelled') rethrow;
      }
      if (photos.keys.every((slot) => slot == 2)) {
        return AutomaticScanResult(
          barcode: detected,
          barcodePoints: detection!.points,
          barcodeSlot: barcodeSlot,
        );
      }
    }
    if (photos.keys.every((slot) => slot == 2)) {
      return AutomaticScanResult(barcode: detected);
    }
    final cloud = await allowCloud();
    current();
    ExtractedLabel? label;
    if (cloud) {
      try {
        final prepared = <int, Uint8List>{};
        for (final entry in photos.entries) {
          prepared[entry.key] = (await VisionPhoto.prepare(entry.value)).bytes;
          current();
        }
        label = await repository.extractPhotos(
          prepared,
          abortTrigger: abortTrigger,
        );
        current();
      } on AppFailure catch (failure) {
        if (failure.kind == 'cancelled') rethrow;
      }
    }
    final localFallback = label == null;
    if (label == null) {
      var front = '', back = '';
      if (photos[0] != null) front = await _ocr.recognize(photos[0]!);
      current();
      if (photos[1] != null) back = await _ocr.recognize(photos[1]!);
      current();
      label = readLocalLabel(front, back);
    }
    // A model-read identity never silently establishes a current catalogue SKU.
    // Optional candidates are displayed for the scanner's visual selection.
    var candidates = <ResearchedCandidate>[];
    var catalogueCandidates = <SearchCandidate>[];
    final name = label.identity['name'] as String?;
    if (name != null && name.trim().length >= 2) {
      try {
        final text = name.trim();
        candidates = (await repository.searchResearch(
          text.substring(0, text.length.clamp(0, 128)),
        )).candidates;
        current();
      } on AppFailure catch (failure) {
        if (failure.kind == 'cancelled') rethrow;
      }
      try {
        final text = name.trim();
        catalogueCandidates = (await repository.search(
          text.substring(0, text.length.clamp(0, 128)),
        )).candidates;
        current();
      } on AppFailure catch (failure) {
        if (failure.kind == 'cancelled') rethrow;
      }
    }
    return AutomaticScanResult(
      barcode: detected,
      label: label,
      candidates: candidates,
      catalogueCandidates: catalogueCandidates,
      localFallback: localFallback,
      barcodePoints: detection?.points ?? const [],
      barcodeSlot: barcodeSlot,
      capturedSlots: List.unmodifiable(photos.keys),
    );
  }

  void cancel() {
    _generation++;
    final abort = _abort;
    if (abort != null && !abort.isCompleted) abort.complete();
    _barcode.cancel();
    _ocr.cancel();
  }

  void dispose() {
    _disposed = true;
    cancel();
    _barcode.dispose();
    _ocr.dispose();
  }
}
