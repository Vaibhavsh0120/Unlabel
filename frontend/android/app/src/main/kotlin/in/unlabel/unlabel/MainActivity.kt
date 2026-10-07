package `in`.unlabel.unlabel

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.os.Handler
import android.os.Looper
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ocrExecutor = Executors.newSingleThreadExecutor()
    private val sessionLock = Any()
    private var activeSession: OcrSession? = null
    private var ocrChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ocrChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "unlabel/local_ocr",
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "recognize" -> recognize(call, result)
                    "cancel" -> {
                        cancelRecognition()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun recognize(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *>
        val bytes = arguments?.get("bytes") as? ByteArray
        val language = arguments?.get("language") as? String
        if (bytes == null || bytes.isEmpty() || bytes.size > MAX_BYTES) {
            result.error("invalid_image", "Choose an image up to 12 MiB.", null)
            return
        }
        if (language != "en" && language != "hi") {
            result.error("unsupported_language", "Choose English or Hindi.", null)
            return
        }
        val session = OcrSession(result)
        synchronized(sessionLock) {
            if (activeSession != null) {
                result.error("ocr_busy", "Another image is still being read.", null)
                return
            }
            activeSession = session
        }
        try {
            ocrExecutor.execute { recognizeInBackground(bytes, language, session) }
        } catch (_: RejectedExecutionException) {
            release(session)
            complete(session) { it.error("ocr_failed", "Local text recognition is unavailable.", null) }
        }
    }

    private fun recognizeInBackground(bytes: ByteArray, language: String, session: OcrSession) {
        var bitmap: Bitmap? = null
        var recognizer: TextRecognizer? = null
        try {
            if (session.cancelled.get()) {
                release(session)
                return
            }
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            val width = bounds.outWidth
            val height = bounds.outHeight
            if (width <= 0 || height <= 0 || width > MAX_EDGE || height > MAX_EDGE ||
                width.toLong() * height.toLong() > MAX_SOURCE_PIXELS
            ) {
                release(session)
                complete(session) { it.error("invalid_image", "Choose a valid image up to 24 megapixels.", null) }
                return
            }
            var sample = 1
            // Ceil both dimensions: odd image edges may round up at decode.
            while (((width.toLong() + sample - 1) / sample) *
                ((height.toLong() + sample - 1) / sample) > MAX_DECODED_PIXELS
            ) {
                sample *= 2
            }
            val options = BitmapFactory.Options().apply {
                inSampleSize = sample
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }
            val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
                ?: throw IllegalArgumentException("Invalid image")
            bitmap = decoded
            // Android's platform EXIF reader is present at our minSdk 24.
            // Normalize all eight orientations before sending pixels to ML Kit.
            val orientation = try {
                ByteArrayInputStream(bytes).use {
                    ExifInterface(it).getAttributeInt(
                        ExifInterface.TAG_ORIENTATION,
                        ExifInterface.ORIENTATION_NORMAL,
                    )
                }
            } catch (_: Exception) {
                ExifInterface.ORIENTATION_NORMAL
            }
            val matrix = orientationMatrix(orientation)
            if (!matrix.isIdentity) {
                val oriented = Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
                bitmap = oriented
                if (oriented !== decoded) decoded.recycle()
            }
            if (session.cancelled.get()) {
                bitmap.recycle()
                release(session)
                return
            }
            val reader = if (language == "hi") {
                TextRecognition.getClient(DevanagariTextRecognizerOptions.Builder().build())
            } else {
                TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            }
            recognizer = reader
            val inputBitmap = requireNotNull(bitmap)
            reader.process(InputImage.fromBitmap(inputBitmap, 0)).addOnCompleteListener { task ->
                // A cancelled request keeps its bitmap/model alive until ML Kit
                // completes, then releases both; it never returns stale text.
                try {
                    if (!session.cancelled.get()) {
                        if (!task.isSuccessful) {
                            complete(session) { it.error("ocr_failed", "Text could not be read on this device.", null) }
                        } else {
                            val text = task.result.text.trim()
                            when {
                                text.isEmpty() -> complete(session) {
                                    it.error("no_text", "No readable label text was found.", null)
                                }
                                text.length > MAX_TEXT -> complete(session) {
                                    it.error("ocr_too_large", "Read one label section at a time.", null)
                                }
                                else -> complete(session) { it.success(text) }
                            }
                        }
                    }
                } finally {
                    reader.close()
                    inputBitmap.recycle()
                    release(session)
                }
            }
        } catch (_: OutOfMemoryError) {
            recognizer?.close()
            bitmap?.recycle()
            release(session)
            complete(session) { it.error("invalid_image", "Choose a smaller image.", null) }
        } catch (_: Exception) {
            recognizer?.close()
            bitmap?.recycle()
            release(session)
            complete(session) { it.error("ocr_failed", "This image could not be read on this device.", null) }
        }
    }

    private fun orientationMatrix(orientation: Int) = Matrix().apply {
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> setScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> setRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> setScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> { setRotate(90f); postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_ROTATE_90 -> setRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> { setRotate(270f); postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_ROTATE_270 -> setRotate(270f)
        }
    }

    private fun complete(session: OcrSession, callback: (MethodChannel.Result) -> Unit) {
        mainHandler.post {
            if (session.completed.compareAndSet(false, true)) {
                if (session.cancelled.get()) {
                    session.result.error("ocr_cancelled", "Text recognition was cancelled.", null)
                } else {
                    callback(session.result)
                }
            }
        }
    }

    private fun release(session: OcrSession) {
        synchronized(sessionLock) {
            if (activeSession === session) activeSession = null
        }
    }

    private fun cancelRecognition() {
        val session = synchronized(sessionLock) { activeSession } ?: return
        session.cancelled.set(true)
        complete(session) { it.error("ocr_cancelled", "Text recognition was cancelled.", null) }
    }

    override fun onDestroy() {
        ocrChannel?.setMethodCallHandler(null)
        ocrChannel = null
        cancelRecognition()
        ocrExecutor.shutdown()
        super.onDestroy()
    }

    private class OcrSession(val result: MethodChannel.Result) {
        val cancelled = AtomicBoolean(false)
        val completed = AtomicBoolean(false)
    }

    companion object {
        private const val MAX_BYTES = 12 * 1024 * 1024
        private const val MAX_EDGE = 8192
        private const val MAX_SOURCE_PIXELS = 24_000_000L
        private const val MAX_DECODED_PIXELS = 4_000_000L
        private const val MAX_TEXT = 12_000
    }
}
