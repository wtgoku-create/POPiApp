package com.popistudio.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var douyinChannel: MethodChannel? = null
    private var speechChannel: MethodChannel? = null
    private var speechInputBridge: SpeechInputBridge? = null
    private var clipboardImageBridge: ClipboardImageBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        douyinChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "art.popi/douyin_login",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                DouyinLoginBridge.handle(this, call, result)
            }
        }
        speechChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "art.popi/speech_input",
        ).also { channel ->
            speechInputBridge = SpeechInputBridge(this, channel).also { bridge ->
                channel.setMethodCallHandler { call, result ->
                    bridge.handle(call, result)
                }
            }
        }
        clipboardImageBridge = ClipboardImageBridge(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        speechInputBridge?.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onStop() {
        speechInputBridge?.dispose()
        super.onStop()
    }

    override fun onDestroy() {
        speechInputBridge?.dispose()
        super.onDestroy()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        speechInputBridge?.dispose()
        clipboardImageBridge?.dispose()
        clipboardImageBridge = null
        speechInputBridge = null
        speechChannel?.setMethodCallHandler(null)
        speechChannel = null
        douyinChannel?.setMethodCallHandler(null)
        douyinChannel = null
        DouyinLoginBridge.dispose()
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
