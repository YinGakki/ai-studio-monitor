import 'native_cookie_manager.dart';
import 'cookie_store.dart';

/// 账号会话切换器 - 封装多账号 Cookie 隔离切换逻辑
///
/// 切换流程（串行）：
///   1. 保存当前账号的 Cookie（按当前浏览的 URL 提取）
///   2. 清空所有 Cookie（影响整个 WebView 全局 Cookie 存储）
///   3. 加载目标账号已保存的 Cookie（如果有）
///   4. flush 到磁盘
///
/// 注意：Android WebView 的 CookieManager 是单例，无法做到同时多账号在线。
/// 本方案是"切换时持久化"，对串行使用场景足够。
class AccountSessionManager {
  String _currentAccount = '';

  String get currentAccount => _currentAccount;

  /// 初始化当前账号（不做 Cookie 切换，仅记录）
  void setCurrent(String accountName) {
    _currentAccount = accountName;
  }

  /// 切换到指定账号的会话上下文
  ///
  /// [currentUrl] 当前 WebView 正在浏览的 URL（用于保存旧账号 Cookie）
  /// [defaultUrl] 目标账号默认打开的 URL（若无保存的 Cookie 上下文）
  /// 返回目标账号应加载的 URL
  Future<String> switchTo({
    required String targetAccount,
    required String currentUrl,
    required String defaultUrl,
  }) async {
    // 1. 保存当前账号 Cookie
    if (_currentAccount.isNotEmpty && currentUrl.isNotEmpty) {
      final cookies = await NativeCookieManager.getCookiesForUrl(currentUrl);
      if (cookies.isNotEmpty) {
        await CookieStore.saveCurrentContext(
          _currentAccount,
          currentUrl,
          cookies,
        );
      }
    }

    // 2. 清空所有 Cookie
    await NativeCookieManager.clearAll();

    // 3. 加载目标账号 Cookie
    final ctx = await CookieStore.load(targetAccount);
    String loadUrl = defaultUrl;
    if (ctx != null && ctx.cookies.isNotEmpty) {
      final cookieList = NativeCookieManager.parseCookieHeader(ctx.cookies);
      if (cookieList.isNotEmpty) {
        // 用保存时的 URL 作为域，确保 Cookie 能正确匹配
        await NativeCookieManager.setCookiesForUrl(ctx.url, cookieList);
        loadUrl = ctx.url;
      }
    }

    // 4. flush
    await NativeCookieManager.flush();

    _currentAccount = targetAccount;
    return loadUrl;
  }

  /// 仅保存当前账号的 Cookie 上下文（不切换）
  Future<void> saveCurrent({required String url}) async {
    if (_currentAccount.isEmpty || url.isEmpty) return;
    final cookies = await NativeCookieManager.getCookiesForUrl(url);
    if (cookies.isNotEmpty) {
      await CookieStore.saveCurrentContext(_currentAccount, url, cookies);
    }
  }
}
