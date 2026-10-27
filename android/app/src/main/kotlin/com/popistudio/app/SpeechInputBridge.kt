package com.popistudio.app

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Bridges Android's platform speech recognizer to one Flutter-owned session. */
class SpeechInputBridge(
    private val activity: Activity,
    private val channel: MethodChannel,
) {
    private data class Session(
        val generation: Long,
        val sessionId: String,
        val locale: String,
        var startResult: MethodChannel.Result?,
        var recognizer: SpeechRecognizer? = null,
        var stopping: Boolean = false,
        var doneSent: Boolean = false,
        var lastTranscript: String? = null,
    )

    private val handler = Handler(Looper.getMainLooper())
    private var generation = 0L
    private var current: Session? = null
    private var permissionRequestInFlight = false
    private var permissionOwnerGeneration: Long? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> start(call, result)
            "stop" -> stop(call.argument<String>("sessionId"), result)
            "cancel" -> cancel(call.argument<String>("sessionId"), result)
            else -> result.notImplemented()
        }
    }

    private fun start(call: MethodCall, result: MethodChannel.Result) {
        val sessionId = call.argument<String>("sessionId")?.trim().orEmpty()
        val locale = call.argument<String>("locale")?.trim().orEmpty()
        if (sessionId.isEmpty() || locale.isEmpty()) {
            result.error("recognition_failed", "A non-empty sessionId and locale are required.", null)
            return
        }

        finishForReplacement()
        val session = Session(++generation, sessionId, locale, result)
        current = session

        if (hasRecordAudioPermission()) {
            beginListening(session)
            return
        }

        permissionOwnerGeneration = session.generation
        if (permissionRequestInFlight) return
        permissionRequestInFlight = true
        try {
            activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), PERMISSION_REQUEST_CODE)
        } catch (_: Exception) {
            permissionRequestInFlight = false
            permissionOwnerGeneration = null
            failSetup(session, "permission_denied", "Microphone permission could not be requested.")
        }
    }

    private fun beginListening(session: Session) {
        if (!owns(session)) return
        val available = try {
            SpeechRecognizer.isRecognitionAvailable(activity)
        } catch (_: Exception) {
            false
        }
        if (!available) {
            failSetup(session, "unavailable", "Speech recognition is unavailable on this device.")
            return
        }

        val recognizer = try {
            SpeechRecognizer.createSpeechRecognizer(activity)
        } catch (_: Exception) {
            failSetup(session, "unavailable", "Speech recognition could not be created.")
            return
        }
        session.recognizer = recognizer
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, session.locale)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
        try {
            recognizer.setRecognitionListener(listenerFor(session))
            recognizer.startListening(intent)
        } catch (_: SecurityException) {
            failSetup(session, "permission_denied", "Microphone permission is required.")
            return
        } catch (_: Exception) {
            failSetup(session, "recognition_failed", "Speech recognition could not be started.")
            return
        }
        handler.postDelayed({
            if (owns(session) && session.startResult != null) {
                failSetup(session, "recognition_failed", "Speech recognition did not become ready.")
            }
        }, START_SETUP_TIMEOUT_MS)
    }

    private fun stop(sessionId: String?, result: MethodChannel.Result) {
        val session = current
        if (session == null || session.sessionId != sessionId) {
            result.success(null)
            return
        }

        session.stopping = true
        if (session.startResult != null) {
            session.startResult?.error("cancelled", "Speech recognition was stopped before it started.", null)
            session.startResult = null
            finish(session, emitDone = true, cancelFirst = true)
            result.success(null)
            return
        }
        val recognizer = session.recognizer
        if (recognizer == null) {
            finish(session, emitDone = true)
            result.success(null)
            return
        }

        result.success(null)
        try {
            recognizer.stopListening()
        } catch (_: Exception) {
            finishWithAsyncError(session, "recognition_failed")
            return
        }
        handler.postDelayed({
            if (owns(session) && session.stopping) finish(session, emitDone = true)
        }, STOP_FINISH_TIMEOUT_MS)
    }

    private fun cancel(sessionId: String?, result: MethodChannel.Result) {
        val session = current
        if (session != null && session.sessionId == sessionId) {
            current = null
            if (permissionOwnerGeneration == session.generation) permissionOwnerGeneration = null
            session.startResult?.error("cancelled", "Speech recognition was cancelled.", null)
            session.startResult = null
            destroy(session, cancelFirst = true)
        }
        result.success(null)
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        permissionRequestInFlight = false
        val ownerGeneration = permissionOwnerGeneration
        permissionOwnerGeneration = null
        val session = current
        if (session == null || session.generation != ownerGeneration || session.startResult == null) return true

        val permissionIndex = permissions.indexOf(Manifest.permission.RECORD_AUDIO)
        val granted = permissionIndex >= 0 &&
            grantResults.getOrNull(permissionIndex) == PackageManager.PERMISSION_GRANTED
        if (granted) {
            beginListening(session)
        } else {
            failSetup(session, "permission_denied", "Microphone permission was denied.")
        }
        return true
    }

    /** Releases microphone access when Flutter detaches or the Activity leaves the foreground. */
    fun dispose() {
        permissionOwnerGeneration = null
        val session = current ?: return
        current = null
        val startResult = session.startResult
        session.startResult = null
        destroy(session, cancelFirst = true)
        if (startResult != null) {
            startResult.error("cancelled", "Speech recognition was interrupted.", null)
            return
        }
        emitEvent(session, type = "error", extra = mapOf("code" to "cancelled"))
        emitDone(session)
    }

    private fun listenerFor(session: Session) = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {
            markListeningStarted(session)
        }

        override fun onBeginningOfSpeech() {
            markListeningStarted(session)
        }

        override fun onRmsChanged(rmsdB: Float) {
            markListeningStarted(session)
        }

        override fun onBufferReceived(buffer: ByteArray?) {
            markListeningStarted(session)
        }

        override fun onEndOfSpeech() {
            markListeningStarted(session)
        }

        override fun onError(error: Int) {
            if (!owns(session)) return
            val code = errorCode(error, session.stopping)
            if (session.startResult != null) {
                failSetup(session, code, "Speech recognition setup failed.")
            } else {
                finishWithAsyncError(session, code)
            }
        }

        override fun onResults(results: Bundle?) {
            if (!owns(session)) return
            markListeningStarted(session)
            val transcript = transcriptFrom(results)
            if (transcript.isNullOrEmpty()) {
                finishWithAsyncError(session, "no_speech")
                return
            }
            emitResult(session, transcript, isFinal = true)
            finish(session, emitDone = true)
        }

        override fun onPartialResults(partialResults: Bundle?) {
            if (!owns(session)) return
            markListeningStarted(session)
            val transcript = transcriptFrom(partialResults) ?: return
            if (transcript.isEmpty() || transcript == session.lastTranscript) return
            emitResult(session, transcript, isFinal = false)
        }

        override fun onEvent(eventType: Int, params: Bundle?) = Unit
    }

    private fun markListeningStarted(session: Session) {
        if (!owns(session)) return
        val result = session.startResult ?: return
        session.startResult = null
        result.success(null)
    }

    private fun transcriptFrom(results: Bundle?): String? =
        results
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()
            ?.trim()

    private fun emitResult(session: Session, transcript: String, isFinal: Boolean) {
        session.lastTranscript = transcript
        emitEvent(
            session,
            type = "result",
            extra = mapOf("text" to transcript, "isFinal" to isFinal),
        )
    }

    private fun finishWithAsyncError(session: Session, code: String) {
        if (!owns(session)) return
        emitEvent(session, type = "error", extra = mapOf("code" to code))
        finish(session, emitDone = true)
    }

    private fun failSetup(session: Session, code: String, message: String) {
        if (!owns(session)) return
        current = null
        if (permissionOwnerGeneration == session.generation) permissionOwnerGeneration = null
        val result = session.startResult
        session.startResult = null
        destroy(session, cancelFirst = true)
        result?.error(code, message, null)
    }

    private fun finishForReplacement() {
        val session = current ?: return
        current = null
        if (permissionOwnerGeneration == session.generation) permissionOwnerGeneration = null
        val startResult = session.startResult
        session.startResult = null
        destroy(session, cancelFirst = true)
        if (startResult != null) {
            startResult.error("cancelled", "Speech recognition was replaced by a new session.", null)
            return
        }
        emitEvent(session, type = "error", extra = mapOf("code" to "cancelled"))
        emitDone(session)
    }

    private fun finish(session: Session, emitDone: Boolean, cancelFirst: Boolean = false) {
        if (!owns(session)) return
        current = null
        if (permissionOwnerGeneration == session.generation) permissionOwnerGeneration = null
        destroy(session, cancelFirst = cancelFirst)
        if (emitDone) emitDone(session)
    }

    private fun destroy(session: Session, cancelFirst: Boolean) {
        val recognizer = session.recognizer ?: return
        session.recognizer = null
        try {
            if (cancelFirst) recognizer.cancel()
        } catch (_: Exception) {
            // Destruction still releases the recognizer if cancellation fails.
        }
        try {
            recognizer.destroy()
        } catch (_: Exception) {
            // The session is already detached, so late callbacks remain ignored.
        }
    }

    private fun emitDone(session: Session) {
        if (session.doneSent) return
        session.doneSent = true
        emitEvent(session, type = "done")
    }

    private fun emitEvent(
        session: Session,
        type: String,
        extra: Map<String, Any> = emptyMap(),
    ) {
        channel.invokeMethod(
            "event",
            mutableMapOf<String, Any>("sessionId" to session.sessionId, "type" to type).apply {
                putAll(extra)
            },
        )
    }

    private fun owns(session: Session): Boolean = current === session

    private fun hasRecordAudioPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    private fun errorCode(error: Int, stopping: Boolean): String = when (error) {
        SpeechRecognizer.ERROR_AUDIO -> "audio"
        SpeechRecognizer.ERROR_NETWORK,
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT,
        SpeechRecognizer.ERROR_SERVER,
        SpeechRecognizer.ERROR_SERVER_DISCONNECTED,
        -> "network"
        SpeechRecognizer.ERROR_NO_MATCH,
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT,
        -> "no_speech"
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "permission_denied"
        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED,
        SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE,
        -> "unavailable"
        SpeechRecognizer.ERROR_CLIENT -> if (stopping) "cancelled" else "recognition_failed"
        else -> "recognition_failed"
    }

    private companion object {
        const val PERMISSION_REQUEST_CODE = 0x504F
        const val START_SETUP_TIMEOUT_MS = 10_000L
        const val STOP_FINISH_TIMEOUT_MS = 3_000L
    }
}
