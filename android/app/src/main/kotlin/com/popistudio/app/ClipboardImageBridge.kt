package com.popistudio.app

import android.app.Activity
import android.content.ClipboardManager
import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/** Reads clipboard images only after Dart reports an explicit user paste action. */
class ClipboardImageBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    init {
        channel.setMethodCallHandler(::handle)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "readImages") {
            result.notImplemented()
            return
        }
        Thread {
            try {
                val images = readImages()
                activity.runOnUiThread { result.success(images) }
            } catch (failure: ClipboardFailure) {
                activity.runOnUiThread { result.error(failure.code, failure.message, null) }
            } catch (_: SecurityException) {
                activity.runOnUiThread {
                    result.error("permission_denied", "Clipboard image access was denied.", null)
                }
            } catch (_: Exception) {
                activity.runOnUiThread {
                    result.error("invalid_content", "The pasted image could not be read.", null)
                }
            }
        }.start()
    }

    private fun readImages(): List<Map<String, Any>> {
        val manager = activity.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = manager.primaryClip ?: return emptyList()
        val resolver = activity.contentResolver
        val output = mutableListOf<Map<String, Any>>()
        var total = 0
        for (index in 0 until clip.itemCount) {
            val item = clip.getItemAt(index)
            val uri = item.uri ?: continue
            val declared = resolver.getType(uri)?.lowercase()
            val mimeType = normalizedMimeType(declared, uri) ?: continue
            if (output.size >= COUNT_LIMIT) {
                throw ClipboardFailure("too_many_images", "Paste at most $COUNT_LIMIT images at once.")
            }
            resolver.openAssetFileDescriptor(uri, "r")?.use { descriptor ->
                if (descriptor.length > BYTE_LIMIT) {
                    throw ClipboardFailure("image_too_large", "A pasted image exceeds 20 MiB.")
                }
            }
            validateDimensions(uri)
            val bytes = resolver.openInputStream(uri)?.use { stream ->
                val sink = ByteArrayOutputStream()
                val buffer = ByteArray(64 * 1024)
                while (true) {
                    val count = stream.read(buffer)
                    if (count < 0) break
                    if (sink.size() + count > BYTE_LIMIT) {
                        throw ClipboardFailure("image_too_large", "A pasted image exceeds 20 MiB.")
                    }
                    if (total + sink.size() + count > BYTE_LIMIT) {
                        throw ClipboardFailure("total_too_large", "Pasted images exceed 20 MiB in total.")
                    }
                    sink.write(buffer, 0, count)
                }
                sink.toByteArray()
            } ?: throw ClipboardFailure("invalid_content", "The pasted image could not be opened.")
            if (bytes.isEmpty()) throw ClipboardFailure("empty", "The pasted image is empty.")
            total += bytes.size
            output += mapOf(
                "name" to safeName(uri, index, mimeType),
                "mimeType" to mimeType,
                "bytes" to bytes,
            )
        }
        return output
    }

    private fun validateDimensions(uri: Uri) {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        activity.contentResolver.openInputStream(uri)?.use { stream ->
            BitmapFactory.decodeStream(stream, null, options)
        } ?: throw ClipboardFailure("invalid_content", "The pasted image could not be opened.")
        val width = options.outWidth
        val height = options.outHeight
        if (width <= 0 || height <= 0) {
            throw ClipboardFailure("invalid_content", "The pasted image dimensions are invalid.")
        }
        if (width > MAX_DIMENSION || height > MAX_DIMENSION || width.toLong() * height > MAX_PIXELS) {
            throw ClipboardFailure("invalid_content", "The pasted image dimensions exceed the safe limit.")
        }
    }

    private fun normalizedMimeType(value: String?, uri: Uri): String? {
        val type = when (value) {
            "image/jpg" -> "image/jpeg"
            else -> value
        }
        if (type in SUPPORTED_TYPES) return type
        if (type?.startsWith("image/") == true) {
            throw ClipboardFailure("unsupported_type", "Only PNG, JPEG, and WebP images can be pasted.")
        }
        return when (uri.lastPathSegment?.substringAfterLast('.', "")?.lowercase()) {
            "png" -> "image/png"
            "jpg", "jpeg" -> "image/jpeg"
            "webp" -> "image/webp"
            else -> null
        }
    }

    private fun safeName(uri: Uri, index: Int, mimeType: String): String {
        val leaf = uri.lastPathSegment?.substringAfterLast('/')?.trim().orEmpty()
        if (leaf.isNotEmpty() && leaf.none { it.code < 32 || it.code == 127 }) return leaf
        val extension = when (mimeType) {
            "image/jpeg" -> "jpg"
            "image/webp" -> "webp"
            else -> "png"
        }
        return "clipboard-image-${index + 1}.$extension"
    }

    private class ClipboardFailure(val code: String, override val message: String) : Exception(message)

    companion object {
        private const val CHANNEL_NAME = "art.popi/clipboard_images"
        private const val BYTE_LIMIT = 20 * 1024 * 1024
        private const val COUNT_LIMIT = 10
        private const val MAX_DIMENSION = 8192
        private const val MAX_PIXELS = 64L * 1024 * 1024
        private val SUPPORTED_TYPES = setOf("image/png", "image/jpeg", "image/webp")
    }
}
