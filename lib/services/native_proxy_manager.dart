import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 原生 WebView 代理管理器 - 通过 platform channel 调用 AndroidX WebKit ProxyController
///
/// 为 WebView 设置全局 HTTP 代理，使所有网络请求（含 JS 发起的）走指定代理。
/// 手机不开 VPN 时，配置局域网/远程代理即可访问 AI Studio。
///
/// 代理规则格式（与 AndroidX ProxyConfig.addProxyRule 一致）：
///   - "ying.host:7890"            → 默认 HTTP 代理
///   - "http://ying.host:7890"     → 显式 HTTP 代理
///   - "socks5://ying.host:7890"   → SOCKS5 代理
class NativeProxyManager {
  static const _channel = MethodChannel('ai_studio_monitor/proxy');

  /// 设置 WebView 代理。
  ///
  /// [proxyRule] 如 "ying.host:7890"；传空字符串等效于清除代理（恢复直连）。
  /// [username]/[password] 可选，用于需要认证的代理。
  ///
  /// 当提供凭证时，会把凭证编码进代理 URL（user:pass@host:port），
  /// 这样所有请求（含 JS fetch/XHR）都自动携带 Proxy-Authorization 头，
  /// 不依赖 onHttpAuthRequest 回调（该回调对 JS 子请求可能不触发）。
  static Future<bool> setProxy(
    String proxyRule, {
    String? username,
    String? password,
  }) async {
    final rule = _buildProxyRule(proxyRule, username, password);
    try {
      final result = await _channel.invokeMethod<bool>('setProxy', {
        'proxyRule': rule,
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

  /// 构建代理规则，有凭证时拼成 user:pass@host:port 格式
  static String _buildProxyRule(
    String proxyRule,
    String? username,
    String? password,
  ) {
    if (proxyRule.isEmpty) return '';
    if (username == null || username.isEmpty) return proxyRule;
    if (password == null || password.isEmpty) return proxyRule;

    // 解析 scheme
    var s = proxyRule.trim();
    String scheme = '';
    for (final sc in ['socks5://', 'socks4://', 'http://', 'https://']) {
      if (s.toLowerCase().startsWith(sc)) {
        scheme = sc;
        s = s.substring(sc.length);
        break;
      }
    }
    // 拼接 scheme://user:encodedPass@host:port
    final encodedPass = Uri.encodeComponent(password);
    return '$scheme$username:$encodedPass@$s';
  }
}
