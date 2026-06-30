import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_store.dart';
import '../theme/colors.dart';
import '../utils/color_ext.dart';
import '../services/native_cookie_manager.dart';
import '../services/cookie_store.dart';
import '../services/proxy_tester.dart';

/// 设置页面 - 管理账号/项目/监控模型/代理
class SettingsScreen extends StatelessWidget {
  final VoidCallback onBack;
  const SettingsScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Container(
      color: AppColors.bg.color,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 标题栏
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                color: AppColors.fgMuted.color,
                onPressed: onBack,
              ),
              Text('设置',
                  style: TextStyle(color: AppColors.fg.color, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),

          // ── 账号与项目 ──
          _SectionTitle(title: '账号与项目'),
          const SizedBox(height: 6),
          ...store.config.accounts.map((acc) => _AccountTile(account: acc)),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => _showAddAccountDialog(context),
            icon: Icon(Icons.add, color: AppColors.info.color, size: 18),
            label: Text('添加账号', style: TextStyle(color: AppColors.info.color)),
          ),

          const Divider(color: Color(0x14FFFFFF), height: 32),

          // ── 监控模型 ──
          _SectionTitle(title: '监控模型'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...store.config.monitoredModels.map((m) => Chip(
                    label: Text(m, style: TextStyle(color: AppColors.fg.color, fontSize: 11)),
                    backgroundColor: AppColors.card.color,
                    side: BorderSide(color: AppColors.borderSolid.color),
                    deleteIconColor: AppColors.destructive.color,
                    onDeleted: () => store.removeMonitoredModel(m),
                  )),
              ActionChip(
                label: Text('+ 添加', style: TextStyle(color: AppColors.info.color, fontSize: 11)),
                backgroundColor: AppColors.muted.color,
                side: BorderSide(color: AppColors.info.color.withValues(alpha: 0.4)),
                onPressed: () => _showAddModelDialog(context),
              ),
            ],
          ),

          const Divider(color: Color(0x14FFFFFF), height: 32),

          // ── 代理 ──
          _SectionTitle(title: '代理'),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '填写后不开 VPN 也可访问 AI Studio；留空恢复直连。格式：host:port',
              style: TextStyle(color: AppColors.fgDim.color, fontSize: 10),
            ),
          ),
          _ProxySection(),

          const Divider(color: Color(0x14FFFFFF), height: 32),

          // ── 账号会话 (Cookie 缓存) ──
          _SectionTitle(title: '账号会话 (Cookie 缓存)'),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              '每个账号的登录 Cookie 单独存储。切换账号时自动恢复，'
              '若登录态失效可在浏览器中重新登录后再次切换以刷新缓存。',
              style: TextStyle(color: AppColors.fgDim.color, fontSize: 10),
            ),
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _clearAllCookies(context),
                icon: Icon(Icons.cleaning_services, size: 16, color: AppColors.warning.color),
                label: Text('清除所有 Cookie 缓存',
                    style: TextStyle(color: AppColors.warning.color, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _clearWebViewCookies(context),
                icon: Icon(Icons.logout, size: 16, color: AppColors.destructive.color),
                label: Text('登出当前 WebView',
                    style: TextStyle(color: AppColors.destructive.color, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllCookies(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card.color,
        title: Text('清除所有 Cookie 缓存', style: TextStyle(color: AppColors.fg.color, fontSize: 14)),
        content: Text('将删除所有账号已保存的 Cookie 上下文。下次切换账号需要重新登录。是否继续？',
            style: TextStyle(color: AppColors.fgMuted.color, fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消', style: TextStyle(color: AppColors.fgMuted.color)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('确定', style: TextStyle(color: AppColors.warning.color)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await CookieStore.clearAll();
    await NativeCookieManager.clearAll();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已清除所有 Cookie 缓存'),
          backgroundColor: AppColors.success.color,
        ),
      );
    }
  }

  Future<void> _clearWebViewCookies(BuildContext context) async {
    await NativeCookieManager.clearAll();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已登出当前 WebView，请在浏览器中重新登录'),
          backgroundColor: AppColors.info.color,
        ),
      );
    }
  }

  void _showAddAccountDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card.color,
        title: Text('添加账号', style: TextStyle(color: AppColors.fg.color, fontSize: 14)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '账号名称',
            hintStyle: TextStyle(color: AppColors.fgDim.color),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.borderSolid.color)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.info.color)),
          ),
          style: TextStyle(color: AppColors.fg.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: AppColors.fgMuted.color)),
          ),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                context.read<AppStore>().addAccount(name);
                Navigator.pop(context);
              }
            },
            child: Text('添加', style: TextStyle(color: AppColors.info.color)),
          ),
        ],
      ),
    );
  }

  void _showAddModelDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card.color,
        title: Text('添加监控模型', style: TextStyle(color: AppColors.fg.color, fontSize: 14)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '如 Gemini 3.5 Flash',
            hintStyle: TextStyle(color: AppColors.fgDim.color),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.borderSolid.color)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.info.color)),
          ),
          style: TextStyle(color: AppColors.fg.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: AppColors.fgMuted.color)),
          ),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                context.read<AppStore>().addMonitoredModel(name);
                Navigator.pop(context);
              }
            },
            child: Text('添加', style: TextStyle(color: AppColors.info.color)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: AppColors.fgMuted.color,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final dynamic account; // Account
  const _AccountTile({required this.account});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card.color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderSolid.color.withValues(alpha: 0.4)),
      ),
      child: ExpansionTile(
        title: Text(account.name as String,
            style: TextStyle(color: AppColors.fg.color, fontSize: 13, fontWeight: FontWeight.w600)),
        iconColor: AppColors.fgMuted.color,
        collapsedIconColor: AppColors.fgMuted.color,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          ...(account.projects as List).map((p) => ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                title: Text(p.name as String,
                    style: TextStyle(color: AppColors.fgMuted.color, fontSize: 12)),
                subtitle: Text(p.url as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.fgDim.color, fontSize: 10)),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, size: 16, color: AppColors.destructive.color),
                  onPressed: () =>
                      store.deleteProject(account.name as String, p.name as String),
                ),
              )),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showAddProjectDialog(context, account.name as String),
                icon: Icon(Icons.add, size: 16, color: AppColors.success.color),
                label: Text('添加项目',
                    style: TextStyle(color: AppColors.success.color, fontSize: 12)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => store.deleteAccount(account.name as String),
                child: Text('删除账号',
                    style: TextStyle(color: AppColors.destructive.color, fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddProjectDialog(BuildContext context, String accountName) {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController(
      text: 'https://aistudio.google.com/rate-limit?timeRange=last-1-day&project=');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card.color,
        title: Text('添加项目 - $accountName',
            style: TextStyle(color: AppColors.fg.color, fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '项目名称',
                labelStyle: TextStyle(color: AppColors.fgDim.color, fontSize: 12),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.borderSolid.color)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.info.color)),
              ),
              style: TextStyle(color: AppColors.fg.color, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: urlCtrl,
              decoration: InputDecoration(
                labelText: '速率限制 URL',
                labelStyle: TextStyle(color: AppColors.fgDim.color, fontSize: 12),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.borderSolid.color)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.info.color)),
              ),
              style: TextStyle(color: AppColors.fg.color, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: AppColors.fgMuted.color)),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final url = urlCtrl.text.trim();
              if (name.isNotEmpty && url.isNotEmpty) {
                context.read<AppStore>().addProject(accountName, name, url);
                Navigator.pop(context);
              }
            },
            child: Text('添加', style: TextStyle(color: AppColors.info.color)),
          ),
        ],
      ),
    );
  }
}

class _ProxySection extends StatefulWidget {
  @override
  State<_ProxySection> createState() => _ProxySectionState();
}

class _ProxySectionState extends State<_ProxySection> {
  TextEditingController? _proxyCtrl;
  TextEditingController? _userCtrl;
  TextEditingController? _passCtrl;
  bool _obscurePass = true;
  bool _testing = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = context.read<AppStore>();
    _proxyCtrl ??= TextEditingController(text: store.config.proxy);
    _userCtrl ??= TextEditingController(text: store.config.proxyUsername);
    _passCtrl ??= TextEditingController(text: store.config.proxyPassword);
  }

  @override
  void dispose() {
    _proxyCtrl?.dispose();
    _userCtrl?.dispose();
    _passCtrl?.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.fgDim.color, fontSize: 12),
        enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.borderSolid.color)),
        focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.info.color)),
      );

  @override
  Widget build(BuildContext context) {
    final proxyCtrl = _proxyCtrl;
    final userCtrl = _userCtrl;
    final passCtrl = _passCtrl;
    if (proxyCtrl == null || userCtrl == null || passCtrl == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 代理地址 + 保存按钮
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: proxyCtrl,
                decoration: _decoration('如 ying.host:7890'),
                style: TextStyle(
                    color: AppColors.fg.color, fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () async {
                final proxy = proxyCtrl.text.trim();
                final user = userCtrl.text.trim();
                final pass = passCtrl.text;
                final ok = await context
                    .read<AppStore>()
                    .setProxy(proxy, username: user, password: pass);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? (proxy.isEmpty ? '已清除代理，恢复直连' : '代理已生效: $proxy')
                        : '代理保存失败，设备可能不支持'),
                    backgroundColor:
                        ok ? AppColors.success.color : AppColors.destructive.color,
                  ),
                );
              },
              child: Text('保存', style: TextStyle(color: AppColors.info.color, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 用户名
        Text('代理认证（可选，需密码的代理填写）',
            style: TextStyle(color: AppColors.fgMuted.color, fontSize: 10)),
        const SizedBox(height: 4),
        TextField(
          controller: userCtrl,
          decoration: _decoration('用户名'),
          style: TextStyle(color: AppColors.fg.color, fontSize: 12),
        ),
        const SizedBox(height: 8),

        // 密码
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: passCtrl,
                obscureText: _obscurePass,
                decoration: _decoration('密码'),
                style: TextStyle(color: AppColors.fg.color, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                _obscurePass ? Icons.visibility_off : Icons.visibility,
                size: 18,
                color: AppColors.fgMuted.color,
              ),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 测试按钮 + 结果
        Row(
          children: [
            TextButton.icon(
              onPressed: _testing
                  ? null
                  : () async {
                      final proxy = proxyCtrl.text.trim();
                      if (proxy.isEmpty) {
                        setState(() {
                          _testResult = '请先填写代理地址';
                          _testSuccess = false;
                        });
                        return;
                      }
                      // 先保存再测试
                      await context.read<AppStore>().setProxy(proxy,
                          username: userCtrl.text.trim(),
                          password: passCtrl.text);
                      setState(() {
                        _testing = true;
                        _testResult = null;
                      });
                      final result =
                          await context.read<AppStore>().testProxy();
                      if (!mounted) return;
                      setState(() {
                        _testing = false;
                        _testResult = result.message;
                        _testSuccess = result.success;
                      });
                    },
              icon: _testing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.info.color,
                      ),
                    )
                  : Icon(Icons.network_check, size: 16, color: AppColors.warning.color),
              label: Text('测试连接',
                  style: TextStyle(color: AppColors.warning.color, fontSize: 12)),
            ),
          ],
        ),
        if (_testResult != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(
                  _testSuccess! ? Icons.check_circle : Icons.error,
                  size: 14,
                  color: _testSuccess!
                      ? AppColors.success.color
                      : AppColors.destructive.color,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _testResult!,
                    style: TextStyle(
                      color: _testSuccess!
                          ? AppColors.success.color
                          : AppColors.destructive.color,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
