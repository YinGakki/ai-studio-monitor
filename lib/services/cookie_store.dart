import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 单个账号保存的 Cookie 上下文
class AccountCookieContext {
  final String accountName;
  final String url;       // 保存 Cookie 时的 URL（决定 Domain）
  final String cookies;   // "key1=val1; key2=val2"
  final String savedAt;

  AccountCookieContext({
    required this.accountName,
    required this.url,
    required this.cookies,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'account_name': accountName,
        'url': url,
        'cookies': cookies,
        'saved_at': savedAt,
      };

  factory AccountCookieContext.fromJson(Map<String, dynamic> j) =>
      AccountCookieContext(
        accountName: j['account_name'] ?? '',
        url: j['url'] ?? '',
        cookies: j['cookies'] ?? '',
        savedAt: j['saved_at'] ?? '',
      );
}

/// 按账号持久化 Cookie 上下文（SharedPreferences）
class CookieStore {
  static const _kPrefix = 'cookie_ctx_';

  static Future<void> save(AccountCookieContext ctx) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kPrefix${ctx.accountName}', json.encode(ctx.toJson()));
  }

  static Future<AccountCookieContext?> load(String accountName) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_kPrefix$accountName');
    if (raw == null) return null;
    try {
      return AccountCookieContext.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String accountName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_kPrefix$accountName');
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_kPrefix));
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  /// 保存指定账号当前 WebView 的 Cookie 上下文
  /// url 通常是当前正在浏览的 AI Studio 页面 URL
  static Future<AccountCookieContext?> saveCurrentContext(
    String accountName,
    String url,
    String cookies,
  ) async {
    if (url.isEmpty || cookies.isEmpty) return null;
    final ctx = AccountCookieContext(
      accountName: accountName,
      url: url,
      cookies: cookies,
      savedAt: DateTime.now().toIso8601String(),
    );
    await save(ctx);
    return ctx;
  }
}
