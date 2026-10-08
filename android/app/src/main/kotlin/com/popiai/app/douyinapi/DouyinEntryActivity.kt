package com.popiai.app.douyinapi

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import com.popiai.app.DouyinLoginBridge
import com.popiai.app.MainActivity

/** Receives the explicit callback from the Douyin SDK. */
class DouyinEntryActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        dispatch(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        dispatch(intent)
    }

    private fun dispatch(intent: Intent) {
        if (DouyinLoginBridge.handleIntent(this, intent)) {
            startActivity(Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            })
        }
        finish()
    }
}
