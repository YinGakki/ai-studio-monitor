import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 代理设置结果
class ProxySetResult {
  final bool success;
  final String message;
  ProxySetResult({required this.success, required this.message});
}

/// 原生 WebView 代理管理器 - 通过 platform channel 调用 AndroidX WebKit ProxyController
///
/// 为 WebView 设置全局 HTTP 代理，使所有网络请求（含 JS 发起的）走指定代理。
/// 有凭证时原生层启动本地中转代理处理认证。
class NativeProxyManager {
  static const _channel = MethodChannel('ai_studio_monitor/proxy');

  /// 设置 WebView 代理。
  ///
  /// [proxyRule] 如 "ying.host:7890"；传空字符串等效于清除代理（恢复直连）。
  /// [username]/[password] 可选，有凭证时原生层自动启动本地中转代理处理认证。
  ///
  /// 返回 [ProxySetResult]，包含成功/失败状态和具体消息。
  static Future<ProxySetResult> setProxy(
    String proxyRule, {
    String? username,
    String? password,
  }) async {
    try {
      final result = await _channel.invokeMethod<dynamic>('setProxy', {
        'proxyRule': proxyRule,
        'username': username ?? '',
        'password': password ?? '',
      });
      // 原生层可能返回 bool 或 Map
      if (result is bool) {
        return ProxySetResult(
          success: result,
          message: result ? '代理已生效' : '代理设置失败',
        );
      }
      if (result is Map) {
        return ProxySetResult(
          success: result['success'] as bool? ?? false,
          message: result['message'] as String? ?? '未知结果',
        );
      }
      return ProxySetResult(success: false, message: '未知返回格式');
    } on PlatformException catch (e) {
      debugPrint('setProxy 失败: ${e.code} ${e.message}');
      return ProxySetResult(
        success: false,
        message: '${e.message ?? e.code}',
      );
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
