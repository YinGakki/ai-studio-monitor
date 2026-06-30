import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../app_store.dart';
import '../theme/colors.dart';
import '../utils/color_ext.dart';
import '../services/account_session_manager.dart';

/// 浏览器页面 - 对应原 AIFloatingWindow 的浏览器容器
///
/// 多账号通过 [AccountSessionManager] 切换 Cookie 上下文实现隔离：
/// 切换账号时自动保存旧账号 Cookie、清空、加载新账号 Cookie，再重载页面。
class BrowserScreen extends StatefulWidget {
  final WebViewController controller;
  final VoidCallback onBackToDashboard;
  final AccountSessionManager sessionManager;

  const BrowserScreen({
    super.key,
    required this.controller,
    required this.onBackToDashboard,
    required this.sessionManager,
  });

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  String _currentUrl = '';
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _setupUrlTracking();
  }

  void _setupUrlTracking() {
    widget.controller.setNavigationDelegate(NavigationDelegate(
      onPageFinished: (url) {
        if (!mounted) return;
        setState(() => _currentUrl = url);
        final store = context.read<AppStore>();
        final acc = widget.sessionManager.currentAccount;
        if (acc.isNotEmpty) {
          store.updateLastUrl(acc, url);
        }
      },
      onHttpAuthRequest: (request) {
        context.read<AppStore>().proxyAuthCallback(request);
      },
    ));
  }

  void _navigateTo(String url) {
    widget.controller.loadRequest(Uri.parse(url));
  }

  /// 切换账号：保存旧账号 Cookie → 清空 → 加载新账号 Cookie → 重载
  Future<void> _switchAccount(String targetAccount, String defaultUrl) async {
    setState(() => _switching = true);
    try {
      final loadUrl = await widget.sessionManager.switchTo(
        targetAccount: targetAccount,
        currentUrl: _currentUrl,
        defaultUrl: defaultUrl,
      );
      // 同步 last_url 到 AppStore
      if (mounted) {
        context.read<AppStore>().updateLastUrl(targetAccount, loadUrl);
      }
      // 等待 Cookie 写入稳定后重载
      await Future.delayed(const Duration(milliseconds: 200));
      _navigateTo(loadUrl);
    } finally {
      if (mounted) {
        setState(() => _switching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    // 首次进入：初始化会话管理器
    if (widget.sessionManager.currentAccount.isEmpty &&
        store.config.accounts.isNotEmpty) {
      final first = store.config.accounts.first;
      widget.sessionManager.setCurrent(first.name);
      if (first.lastUrl.isNotEmpty && _currentUrl.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateTo(first.lastUrl);
        });
      }
    }

    final quickLinks = <({String label, String url})>[
      (label: 'AI Studio', url: 'https://aistudio.google.com/projects'),
      (label: '速率限制', url: 'https://aistudio.google.com/rate-limit?timeRange=last-1-day'),
      (label: 'Google Cloud', url: 'https://console.cloud.google.com/'),
      (label: '新建项目', url: 'https://console.cloud.google.com/projectcreate'),
    ];

    return Container(
      color: AppColors.bg.color,
      child: Column(
        children: [
          // 导航条
          Container(
            color: AppColors.header.color,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.dashboard, size: 18),
                  color: AppColors.info.color,
                  tooltip: '返回面板',
                  onPressed: widget.onBackToDashboard,
                ),
                const SizedBox(width: 4),
                // 账号下拉
                if (store.config.accounts.isNotEmpty)
                  DropdownButton<String>(
                    value: widget.sessionManager.currentAccount.isNotEmpty
                        ? widget.sessionManager.currentAccount
                        : store.config.accounts.first.name,
                    dropdownColor: AppColors.card.color,
                    style: TextStyle(color: AppColors.fgMuted.color, fontSize: 12),
                    underline: const SizedBox(),
                    items: store.config.accounts
                        .map((a) => DropdownMenuItem(
                              value: a.name,
                              child: Text(a.name),
                            ))
                        .toList(),
                    onChanged: _switching
                        ? null
                        : (v) {
                            if (v == null) return;
                            final acc = store.config.accounts.firstWhere((a) => a.name == v);
                            final url = acc.lastUrl.isNotEmpty
                                ? acc.lastUrl
                                : 'https://aistudio.google.com/projects';
                            _switchAccount(v, url);
                          },
                  ),
                const SizedBox(width: 4),
                if (_switching)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppColors.warning.color,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '切换中',
                          style: TextStyle(color: AppColors.warning.color, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                ...quickLinks.map((link) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: TextButton(
                        onPressed: _switching ? null : () => _navigateTo(link.url),
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.muted.color,
                          foregroundColor: AppColors.fgMuted.color,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        child: Text(link.label),
                      ),
                    )),
                const Spacer(),
              ],
            ),
          ),
          // URL 显示
          Container(
            color: AppColors.muted.color,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Text(
              _currentUrl.isEmpty ? '未加载' : _currentUrl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.fgDim.color, fontSize: 10, fontFamily: 'monospace'),
            ),
          ),
          // WebView
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: widget.controller),
                if (_switching)
                  Container(
                    color: AppColors.bg.color.withValues(alpha: 0.7),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.info.color),
                          const SizedBox(height: 8),
                          Text(
                            '正在切换账号会话…',
                            style: TextStyle(color: AppColors.fgMuted.color, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
