import Flutter
import ImageIO
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var localOcr: LocalOcrAdapter?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    localOcr?.dispose()
    localOcr = LocalOcrAdapter(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

/// Apple's bundled Vision framework reads label text locally; no Pods or cloud.
private final class LocalOcrAdapter {
  private static let maxBytes = 12 * 1024 * 1024
  private static let maxPixels = 24_000_000
  private static let maxEdge = 8192
  private static let maxText = 12_000
  private let channel: FlutterMethodChannel
  private let queue = DispatchQueue(label: "in.unlabel.local-ocr", qos: .userInitiated)
  private let stateLock = NSLock()
  private var active: OcrSession?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "unlabel/local_ocr", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "ocr_failed", message: "Local text recognition is unavailable.", details: nil))
        return
      }
      switch call.method {
      case "recognize": self.recognize(call, result: result)
      case "cancel":
        self.cancel()
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func recognize(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
      let typedData = arguments["bytes"] as? FlutterStandardTypedData,
      !typedData.data.isEmpty, typedData.data.count <= Self.maxBytes
    else {
      result(FlutterError(code: "invalid_image", message: "Choose an image up to 12 MiB.", details: nil))
      return
    }
    guard let language = arguments["language"] as? String,
      language == "en" || language == "hi"
    else {
      result(FlutterError(code: "unsupported_language", message: "Choose English or Hindi.", details: nil))
      return
    }
    let session = OcrSession(result: result)
    stateLock.lock()
    if active != nil {
      stateLock.unlock()
      result(FlutterError(code: "ocr_busy", message: "Another image is still being read.", details: nil))
      return
    }
    active = session
    stateLock.unlock()
    let data = typedData.data
    queue.async { [self] in
      autoreleasepool {
        self.read(data, language: language, session: session)
      }
    }
  }

  private func read(_ data: Data, language: String, session: OcrSession) {
    defer { release(session) }
    if session.isCancelled { return }
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      CGImageSourceGetCount(source) > 0,
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let widthValue = properties[kCGImagePropertyPixelWidth] as? NSNumber,
      let heightValue = properties[kCGImagePropertyPixelHeight] as? NSNumber
    else {
      fail(session, code: "invalid_image", message: "Choose a valid label image.")
      return
    }
    let width = widthValue.intValue
    let height = heightValue.intValue
    guard width > 0, height > 0, width <= Self.maxEdge, height <= Self.maxEdge,
      width * height <= Self.maxPixels
    else {
      fail(session, code: "invalid_image", message: "Choose an image up to 24 megapixels.")
      return
    }
    // Decode a bounded thumbnail and apply EXIF orientation without writing a photo file.
    let thumbnailOptions: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: 2000,
      kCGImageSourceShouldCacheImmediately: true,
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
      fail(session, code: "invalid_image", message: "This image could not be decoded.")
      return
    }
    if session.isCancelled { return }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    // Package names, amounts and units must not be silently spell-corrected.
    request.usesLanguageCorrection = false
    do {
      let supported = try request.supportedRecognitionLanguages()
      guard let selected = supported.first(where: { $0 == language || $0.hasPrefix(language + "-") }) else {
        fail(
          session,
          code: "unsupported_language",
          message: language == "hi"
            ? "Hindi text recognition is unavailable on this iPhone. Enter the label text manually."
            : "English text recognition is unavailable on this device. Enter the label text manually."
        )
        return
      }
      request.recognitionLanguages = [selected]
      if language == "hi", let english = supported.first(where: { $0.hasPrefix("en-") }) {
        request.recognitionLanguages.append(english)
      }
      guard session.install(request) else { return }
      let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
      try handler.perform([request])
      if session.isCancelled { return }
      let text = (request.results ?? [])
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      guard !text.isEmpty else {
        fail(session, code: "no_text", message: "No readable label text was found.")
        return
      }
      guard text.utf16.count <= Self.maxText else {
        fail(session, code: "ocr_too_large", message: "Read one label section at a time.")
        return
      }
      session.finish(text)
    } catch {
      if !session.isCancelled {
        fail(session, code: "ocr_failed", message: "This image could not be read on this device.")
      }
    }
  }

  private func fail(_ session: OcrSession, code: String, message: String) {
    session.finish(FlutterError(code: code, message: message, details: nil))
  }

  private func release(_ session: OcrSession) {
    session.clearRequest()
    stateLock.lock()
    if active === session { active = nil }
    stateLock.unlock()
  }

  private func cancel() {
    stateLock.lock()
    let session = active
    stateLock.unlock()
    session?.cancel()
  }

  func dispose() {
    channel.setMethodCallHandler(nil)
    cancel()
  }

  // A finished background job can release the last adapter reference. Keep
  // channel registration changes in dispose(), which AppDelegate calls on UI.
  deinit { cancel() }
}

/// Cancellation and completion share one guarded callback, always on the UI thread.
private final class OcrSession {
  private let result: FlutterResult
  private let lock = NSLock()
  private var cancelled = false
  private var completed = false
  private var request: VNRecognizeTextRequest?

  init(result: @escaping FlutterResult) { self.result = result }

  var isCancelled: Bool {
    lock.lock()
    defer { lock.unlock() }
    return cancelled
  }

  func install(_ request: VNRecognizeTextRequest) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    if cancelled { return false }
    self.request = request
    return true
  }

  func clearRequest() {
    lock.lock()
    request = nil
    lock.unlock()
  }

  func cancel() {
    lock.lock()
    cancelled = true
    let currentRequest = request
    lock.unlock()
    currentRequest?.cancel()
    finish(FlutterError(code: "ocr_cancelled", message: "Text recognition was cancelled.", details: nil))
  }

  func finish(_ value: Any?) {
    DispatchQueue.main.async { [self] in
      lock.lock()
      if completed {
        lock.unlock()
        return
      }
      completed = true
      let finalValue: Any? = cancelled
        ? FlutterError(code: "ocr_cancelled", message: "Text recognition was cancelled.", details: nil)
        : value
      lock.unlock()
      result(finalValue)
    }
  }
}
