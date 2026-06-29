import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_store.dart';
import '../theme/colors.dart';
import '../utils/color_ext.dart';

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
          const SizedBox(height: 6),
          _ProxyField(),
        ],
      ),
    );
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

class _ProxyField extends StatefulWidget {
  @override
  State<_ProxyField> createState() => _ProxyFieldState();
}

class _ProxyFieldState extends State<_ProxyField> {
  TextEditingController? _ctrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = context.read<AppStore>();
    _ctrl ??= TextEditingController(text: store.config.proxy);
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    if (ctrl == null) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              hintText: '如 127.0.0.1:7890',
              hintStyle: TextStyle(color: AppColors.fgDim.color, fontSize: 12),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.borderSolid.color)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.info.color)),
            ),
            style: TextStyle(color: AppColors.fg.color, fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () {
            context.read<AppStore>().config.setProxy(ctrl.text.trim());
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('代理已保存'), backgroundColor: AppColors.success.color),
            );
          },
          child: Text('保存', style: TextStyle(color: AppColors.info.color, fontSize: 12)),
        ),
      ],
    );
  }
}
