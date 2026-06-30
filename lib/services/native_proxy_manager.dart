import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 原生 WebView 代理管理器 - 通过 platform channel 调用 AndroidX WebKit ProxyController
///
/// 为 WebView 设置全局 HTTP 代理，使所有网络请求（含 JS 发起的）走指定代理。
/// 手机不开 VPN 时，配置局域网/远程代理即可访问 AI Studio。
///
/// 代理规则格式：
///   - "ying.host:7890"            → 默认 HTTP 代理
///   - "http://ying.host:7890"     → 显式 HTTP 代理
///
/// 代理认证：
///   有凭证时原生层启动本地中转代理（127.0.0.1:随机端口），
///   WebView 连本地代理（无认证），本地代理再连真实代理（带认证）。
///   这样 WebView 永远不会遇到 407，所有请求（含 JS fetch/XHR）都能正常工作。
class NativeProxyManager {
  static const _channel = MethodChannel('ai_studio_monitor/proxy');

  /// 设置 WebView 代理。
  ///
  /// [proxyRule] 如 "ying.host:7890"；传空字符串等效于清除代理（恢复直连）。
  /// [username]/[password] 可选，有凭证时原生层自动启动本地中转代理处理认证。
  static Future<bool> setProxy(
    String proxyRule, {
    String? username,
    String? password,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('setProxy', {
        'proxyRule': proxyRule,
        'username': username ?? '',
        'password': password ?? '',
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('setProxy 失败: ${e.code} ${e.message}');
      return false;
    }
  }

  /// 清除代理（恢复直连）
  static Future<bool> clearProxy() async {
    try {
      final result = await _channel.invokeMethod<bool>('clearProxy');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('clearProxy 失败: ${e.code} ${e.message}');
      return false;
    }
  }
}
