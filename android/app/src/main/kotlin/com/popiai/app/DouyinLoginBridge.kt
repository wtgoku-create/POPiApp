package com.popiai.app

import android.app.Activity
import android.content.Intent
import com.bytedance.sdk.open.aweme.authorize.model.Authorization
import com.bytedance.sdk.open.aweme.common.handler.IApiEventHandler
import com.bytedance.sdk.open.aweme.common.model.BaseReq
import com.bytedance.sdk.open.aweme.common.model.BaseResp
import com.bytedance.sdk.open.douyin.DouYinOpenApiFactory
import com.bytedance.sdk.open.douyin.DouYinOpenConfig
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Keeps the pending authorization across the separate SDK callback Activity. */
object DouyinLoginBridge {
    private var pendingResult: MethodChannel.Result? = null
    private var pendingState: String? = null

    fun handle(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "authorize" -> authorize(activity, call, result)
            "cancelAuthorization" -> {
                if (pendingState != null && call.argument<String>("state") == pendingState) {
                    finish(mapOf("status" to "canceled"))
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun authorize(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.success(mapOf("status" to "failed", "reason" to "authorization_in_progress"))
            return
        }
        val clientKey = call.argument<String>("clientKey")?.trim().orEmpty()
        val state = call.argument<String>("state")?.trim().orEmpty()
        if (clientKey.isEmpty() || state.isEmpty()) {
            result.success(mapOf("status" to "failed", "reason" to "invalid_configuration"))
            return
        }
        pendingResult = result
        pendingState = state
        try {
            if (!DouYinOpenApiFactory.init(DouYinOpenConfig(clientKey))) {
                finish(mapOf("status" to "failed", "reason" to "sdk_registration_failed"))
                return
            }
            val api = DouYinOpenApiFactory.create(activity)
            if (!api.isAppInstalled || !api.isAppSupportAuthorization) {
                finish(mapOf("status" to "unavailable", "reason" to "douyin_unavailable"))
                return
            }
            val request = Authorization.Request().apply {
                this.clientKey = clientKey
                this.state = state
                scope = "user_info"
                callerLocalEntry = "com.popiai.app.douyinapi.DouyinEntryActivity"
            }
            if (!api.authorize(request)) {
                finish(mapOf("status" to "failed", "reason" to "sdk_launch_failed"))
            }
        } catch (_: Exception) {
            finish(mapOf("status" to "failed", "reason" to "sdk_exception"))
        }
    }

    /** Unsolicited, expired and mismatched callbacks cannot complete a login. */
    fun handleIntent(activity: Activity, intent: Intent): Boolean {
        if (pendingResult == null) return false
        var completed = false
        try {
            DouYinOpenApiFactory.create(activity).handleIntent(intent, object : IApiEventHandler {
                override fun onReq(request: BaseReq) = Unit

                override fun onResp(response: BaseResp) {
                    if (response !is Authorization.Response || response.state != pendingState) return
                    val code = response.authCode?.trim().orEmpty()
                    val payload = when {
                        response.isCancel -> mapOf("status" to "canceled")
                        response.isSuccess && code.isNotEmpty() -> mapOf(
                            "status" to "authorized", "code" to code, "state" to pendingState!!,
                        )
                        else -> mapOf(
                            "status" to "failed", "reason" to "sdk_authorization_failed",
                            "errorCode" to response.errorCode.toString(),
                        )
                    }
                    finish(payload)
                    completed = true
                }

                override fun onErrorIntent(intent: Intent) = Unit
            })
        } catch (_: Exception) {
            // An invalid external intent must not cancel an unrelated pending request.
        }
        return completed
    }

    fun dispose() {
        finish(mapOf("status" to "canceled"))
    }

    private fun finish(response: Map<String, String>) {
        val result = pendingResult
        pendingResult = null
        pendingState = null
        result?.success(response)
    }
}
