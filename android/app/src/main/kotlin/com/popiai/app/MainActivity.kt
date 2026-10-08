package com.popiai.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var douyinChannel: MethodChannel? = null

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
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        douyinChannel?.setMethodCallHandler(null)
        douyinChannel = null
        DouyinLoginBridge.dispose()
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
