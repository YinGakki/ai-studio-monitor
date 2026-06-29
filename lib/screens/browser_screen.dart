import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../app_store.dart';
import '../theme/colors.dart';
import '../utils/color_ext.dart';

/// 浏览器页面 - 对应原 AIFloatingWindow 的浏览器容器
class BrowserScreen extends StatefulWidget {
  final WebViewController controller;
  final VoidCallback onBackToDashboard;

  const BrowserScreen({
    super.key,
    required this.controller,
    required this.onBackToDashboard,
  });

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  String _currentUrl = '';
  String _currentAccount = '';

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
        final acc = _currentAccount;
        if (acc.isNotEmpty) {
          store.updateLastUrl(acc, url);
        }
      },
    ));
  }

  void _navigateTo(String url) {
    widget.controller.loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (_currentAccount.isEmpty && store.config.accounts.isNotEmpty) {
      _currentAccount = store.config.accounts.first.name;
      final lastUrl = store.config.accounts.first.lastUrl;
      if (lastUrl.isNotEmpty && _currentUrl.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateTo(lastUrl);
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
                    value: _currentAccount.isNotEmpty
                        ? _currentAccount
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
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _currentAccount = v);
                      final acc = store.config.accounts.firstWhere((a) => a.name == v);
                      final url = acc.lastUrl.isNotEmpty
                          ? acc.lastUrl
                          : 'https://aistudio.google.com/projects';
                      _navigateTo(url);
                    },
                  ),
                const Spacer(),
                ...quickLinks.map((link) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: TextButton(
                        onPressed: () => _navigateTo(link.url),
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
            child: WebViewWidget(controller: widget.controller),
          ),
        ],
      ),
    );
  }
}
