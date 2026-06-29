package com.aistudio.monitor

import android.webkit.CookieManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Cookie 隔离插件
 *
 * 通过 Android 原生 CookieManager 暴露 Cookie 读写能力给 Dart 端，
 * 能读取包括 HttpOnly 在内的所有 Cookie（JS 的 document.cookie 读不到 HttpOnly）。
 *
 * 暴露方法：
 *  - getCookies(url) → "key1=val1; key2=val2" 字符串
 *  - setCookies(url, cookies: List<String>) → bool
 *  - clearAll() → bool
 *  - flush() → bool（强制写入持久化存储）
 */
class CookiePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        // 确保接受第三方 Cookie（登录回调常用）
        CookieManager.getInstance().setAcceptCookie(true)
        CookieManager.getInstance().setAcceptThirdPartyCookies(binding.applicationContext, true)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val cm = CookieManager.getInstance()
        try {
            when (call.method) {
                "getCookies" -> {
                    val url = call.argument<String>("url") ?: ""
                    if (url.isEmpty()) {
                        result.success("")
                        return
                    }
                    // getCookie 返回 "key1=val1; key2=val2" 形式
                    val cookies = cm.getCookie(url) ?: ""
                    result.success(cookies)
                }
                "setCookies" -> {
                    val url = call.argument<String>("url") ?: ""
                    val cookies = call.argument<List<String>>("cookies") ?: emptyList()
                    if (url.isEmpty()) {
                        result.success(false)
                        return
                    }
                    cookies.forEach { cm.setCookie(url, it) }
                    cm.flush()
                    result.success(true)
                }
                "clearAll" -> {
                    cm.removeAllCookies { cleared ->
                        cm.flush()
                        result.success(cleared)
                    }
                }
                "flush" -> {
                    cm.flush()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("cookie_error", e.message ?: "unknown", null)
        }
    }

    companion object {
        private const val CHANNEL_NAME = "ai_studio_monitor/cookie"
    }
}
