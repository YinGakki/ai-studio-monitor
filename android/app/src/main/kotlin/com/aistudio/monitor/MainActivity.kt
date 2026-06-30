package com.aistudio.monitor

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 注册 Cookie 隔离插件
        flutterEngine.plugins.add(CookiePlugin())
        // 注册 WebView 代理插件（不开 VPN 时走 HTTP 代理）
        flutterEngine.plugins.add(ProxyPlugin())
    }
}
