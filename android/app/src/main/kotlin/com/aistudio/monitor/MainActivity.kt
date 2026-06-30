package com.aistudio.monitor

import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 启用 WebView 远程调试（chrome://inspect）
        WebView.setWebContentsDebuggingEnabled(true)
        // 注册 Cookie 隔离插件
        flutterEngine.plugins.add(CookiePlugin())
        // 注册 WebView 代理插件（不开 VPN 时走 HTTP 代理）
        flutterEngine.plugins.add(ProxyPlugin())
    }
}
