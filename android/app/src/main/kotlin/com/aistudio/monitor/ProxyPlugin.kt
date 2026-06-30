package com.aistudio.monitor

import androidx.webkit.ProxyController
import androidx.webkit.ProxyConfig
import androidx.webkit.WebViewFeature
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * WebView 代理插件
 *
 * 通过 AndroidX WebKit 的 ProxyController 为 WebView 设置全局 HTTP 代理，
 * 使 WebView 内所有网络请求（含 JS 发起的 fetch/XHR）走指定代理。
 * 用于手机不开 VPN 时，通过局域网/远程代理访问 AI Studio。
 *
 * 暴露方法：
 *  - setProxy(proxyRule) → bool
 *      proxyRule 如 "ying.host:7890" 或 "http://ying.host:7890"
 *      传空字符串等效于清除代理（恢复直连）
 *  - clearProxy() → bool
 *      清除代理，恢复直连
 *
 * 要求设备支持 WebViewFeature.PROXY_OVERRIDE（API 21+，项目 minSdk=21 满足）。
 */
class ProxyPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "setProxy" -> {
                    val proxyRule = call.argument<String>("proxyRule") ?: ""
                    if (proxyRule.isEmpty()) {
                        // 空字符串 → 清除代理，恢复直连
                        clearProxyOverride(result)
                        return
                    }
                    if (!WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE)) {
                        result.error("proxy_unsupported",
                            "设备 WebView 不支持 PROXY_OVERRIDE 特性", null)
                        return
                    }
                    val proxyController = ProxyController.getInstance()
                    // addProxyRule 接受 "[scheme://]host[:port]"，无 scheme 时默认 HTTP
                    val config = ProxyConfig.Builder()
                        .addProxyRule(proxyRule.trim())
                        .build()
                    proxyController.setProxyOverride(config, Runnable {
                        result.success(true)
                    })
                }
                "clearProxy" -> {
                    clearProxyOverride(result)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("proxy_error", e.message ?: "unknown", null)
        }
    }

    private fun clearProxyOverride(result: MethodChannel.Result) {
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE)) {
            result.error("proxy_unsupported",
                "设备 WebView 不支持 PROXY_OVERRIDE 特性", null)
            return
        }
        ProxyController.getInstance().clearProxyOverride(Runnable {
            result.success(true)
        })
    }

    companion object {
        private const val CHANNEL_NAME = "ai_studio_monitor/proxy"
    }
}
