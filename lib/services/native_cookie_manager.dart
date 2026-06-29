import 'package:flutter/services.dart';

/// 原生 Cookie 管理代理 - 通过 platform channel 调用 Android CookieManager
///
/// 能读取包括 HttpOnly 在内的所有 Cookie（JS document.cookie 读不到 HttpOnly），
/// 用于多账号 Cookie 隔离。
class NativeCookieManager {
  static const _channel = MethodChannel('ai_studio_monitor/cookie');

  /// 获取指定 URL 的所有 Cookie 字符串
  /// 返回格式："key1=val1; key2=val2"
  static Future<String> getCookiesForUrl(String url) async {
    try {
      final result = await _channel.invokeMethod<String>('getCookies', {'url': url});
      return result ?? '';
    } on PlatformException {
      return '';
    }
  }

  /// 为指定 URL 设置一组 Cookie
  /// cookies 列表元素格式："key=value"（可选附加 Path/Domain/Secure 等属性）
  static Future<bool> setCookiesForUrl(String url, List<String> cookies) async {
    try {
      final result = await _channel.invokeMethod<bool>('setCookies', {
        'url': url,
        'cookies': cookies,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 清空所有 Cookie（影响整个 WebView Cookie 存储）
  static Future<bool> clearAll() async {
    try {
      final result = await _channel.invokeMethod<bool>('clearAll');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 强制刷新 Cookie 持久化到磁盘
  static Future<bool> flush() async {
    try {
      final result = await _channel.invokeMethod<bool>('flush');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 把 "key1=val1; key2=val2" 拆分成 ["key1=val1", "key2=val2"]
  static List<String> parseCookieHeader(String header) {
    if (header.isEmpty) return [];
    return header
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.contains('='))
        .toList();
  }
}
