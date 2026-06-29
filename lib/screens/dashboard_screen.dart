import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../app_store.dart';
import '../theme/colors.dart';
import '../utils/color_ext.dart';
import '../widgets/stat_card.dart';
import '../widgets/model_avail_card.dart';
import '../models/models.dart';

/// 数据面板 - 对应原 DashboardWidget
class DashboardScreen extends StatelessWidget {
  final WebViewController webController;
  final VoidCallback onSwitchToBrowser;

  const DashboardScreen({
    super.key,
    required this.webController,
    required this.onSwitchToBrowser,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStore>(builder: (context, store, _) {
      final data = store.buildProjectModelData();
      final monitored = store.config.monitoredModels;
      final activePkeys = data.keys.toList();

      // 概览统计
      final accountCount = store.config.accounts.length;
      final projectCount = store.config.accounts.fold<int>(
          0, (s, a) => s + a.projects.length);
      final modelCount = _collectModelNames(data).length;
      final extractCount = store.latestUsage.length;
      String latestTime = '--';
      if (store.latestUsage.isNotEmpty) {
        final times = store.latestUsage
            .map((u) => u.checkTime)
            .where((t) => t.isNotEmpty)
            .toList();
        if (times.isNotEmpty) {
          latestTime = times.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
          if (latestTime.contains(' ')) {
            latestTime = latestTime.split(' ').last.substring(0, 5);
          }
        }
      }

      return Container(
        color: AppColors.bg.color,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            // ── 顶部操作栏 ──
            _TopBar(
              store: store,
              onRefresh: () => store.refreshAll(webController),
              onSwitchToBrowser: onSwitchToBrowser,
            ),
            const SizedBox(height: 8),

            // ── 概览卡片 ──
            Row(
              children: [
                StatCard(label: '账号', value: '$accountCount', colorHex: AppColors.info),
                const SizedBox(width: 6),
                StatCard(label: '项目', value: '$projectCount', colorHex: AppColors.success),
                const SizedBox(width: 6),
                StatCard(label: '模型', value: '$modelCount', colorHex: AppColors.warning),
                const SizedBox(width: 6),
                StatCard(label: '提取', value: '$extractCount', colorHex: AppColors.fgDim),
                const SizedBox(width: 6),
                StatCard(label: '最近', value: latestTime, colorHex: AppColors.fgDim),
              ],
            ),
            const SizedBox(height: 8),

            // ── 可用性矩阵 ──
            if (activePkeys.isEmpty)
              _EmptyState(onSwitchToBrowser: onSwitchToBrowser)
            else
              ...store.viewMode == 'model'
                  ? _buildByModel(store, data, monitored, activePkeys)
                  : _buildByProject(store, data, monitored, activePkeys),
          ],
        ),
      );
    });
  }

  Set<String> _collectModelNames(Map<String, Map<String, ModelUsage>> data) {
    final names = <String>{};
    for (final m in data.values) {
      names.addAll(m.keys);
    }
    return names;
  }

  List<Widget> _buildByModel(
    AppStore store,
    Map<String, Map<String, ModelUsage>> data,
    List<String> monitored,
    List<String> activePkeys,
  ) {
    final cards = <Widget>[];
    for (var i = 0; i < monitored.length; i++) {
      final mk = monitored[i];
      final colorHex = AppColors.cardColors[i % AppColors.cardColors.length];
      final blocks = <BlockData>[];
      int totalCur = 0;
      int totalMax = 0;

      for (final pkey in activePkeys) {
        final parts = pkey.split('|');
        final pname = parts.last;
        final md = data[pkey]?[mk];
        if (md != null && md.rpdCur != null) {
          blocks.add(BlockData(
            name: pname,
            rpd: md.rpdCur,
            rpdMax: md.rpdMax,
            accountName: parts.first,
            projectName: pname,
          ));
          totalCur += md.rpdCur ?? 0;
          totalMax += md.rpdMax ?? 0;
        } else {
          blocks.add(BlockData(
            name: pname,
            accountName: parts.first,
            projectName: pname,
          ));
        }
      }

      final summary = totalMax > 0 ? 'RPD $totalCur/$totalMax' : '';
      cards.add(ModelAvailCard(
        title: mk,
        colorHex: colorHex,
        blocks: blocks,
        summaryText: summary,
        totalRpdCur: totalMax > 0 ? totalCur : null,
        totalRpdMax: totalMax > 0 ? totalMax : null,
      ));
    }
    return cards;
  }

  List<Widget> _buildByProject(
    AppStore store,
    Map<String, Map<String, ModelUsage>> data,
    List<String> monitored,
    List<String> activePkeys,
  ) {
    final cards = <Widget>[];
    for (var i = 0; i < activePkeys.length; i++) {
      final pkey = activePkeys[i];
      final parts = pkey.split('|');
      final pname = parts.last;
      final colorHex = AppColors.cardColors[i % AppColors.cardColors.length];
      final blocks = <BlockData>[];
      int projCur = 0;
      int projMax = 0;

      for (final mk in monitored) {
        final md = data[pkey]?[mk];
        if (md != null && md.rpdCur != null) {
          blocks.add(BlockData(
            name: mk,
            rpd: md.rpdCur,
            rpdMax: md.rpdMax,
            accountName: parts.first,
            projectName: pname,
          ));
          projCur += md.rpdCur ?? 0;
          projMax += md.rpdMax ?? 0;
        } else {
          blocks.add(BlockData(
            name: mk,
            accountName: parts.first,
            projectName: pname,
          ));
        }
      }

      cards.add(ModelAvailCard(
        title: pname,
        colorHex: colorHex,
        blocks: blocks,
        totalRpdCur: projMax > 0 ? projCur : null,
        totalRpdMax: projMax > 0 ? projMax : null,
      ));
    }
    return cards;
  }
}

class _TopBar extends StatelessWidget {
  final AppStore store;
  final VoidCallback onRefresh;
  final VoidCallback onSwitchToBrowser;
  const _TopBar({
    required this.store,
    required this.onRefresh,
    required this.onSwitchToBrowser,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: store.isRefreshing ? null : onRefresh,
          icon: store.isRefreshing
              ? const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh, size: 16),
          label: Text(
            store.isRefreshing
                ? '刷新中 ${store.refreshSuccess}/${store.refreshTotal}'
                : '刷新全部用量',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.muted.color,
            foregroundColor: AppColors.info.color,
            side: BorderSide(color: AppColors.info.color),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 6),
        _ViewToggle(
          label: '按模型',
          active: store.viewMode == 'model',
          onTap: () => store.setViewMode('model'),
        ),
        const SizedBox(width: 4),
        _ViewToggle(
          label: '按项目',
          active: store.viewMode == 'project',
          onTap: () => store.setViewMode('project'),
        ),
        const Spacer(),
        if (store.statusText.isNotEmpty)
          Flexible(
            child: Text(
              store.statusText,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.fgDim.color,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.article, size: 18),
          color: AppColors.fgDim.color,
          tooltip: '操作日志',
          onPressed: () => _showLogDialog(context),
        ),
        IconButton(
          icon: const Icon(Icons.list, size: 18),
          color: AppColors.fgDim.color,
          tooltip: '浏览器',
          onPressed: onSwitchToBrowser,
        ),
      ],
    );
  }

  void _showLogDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card.color,
        title: Text('操作日志', style: TextStyle(color: AppColors.fg.color, fontSize: 14)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: store.logs.length,
            itemBuilder: (_, i) {
              final log = store.logs[i];
              final color = {
                'info': AppColors.fgDim,
                'success': AppColors.success,
                'warn': AppColors.warning,
                'error': AppColors.destructive,
              }[log.type] ?? AppColors.fgDim;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${log.time} ${log.detail}',
                  style: TextStyle(color: color.color, fontSize: 11, fontFamily: 'monospace'),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('关闭', style: TextStyle(color: AppColors.fgMuted.color)),
          ),
        ],
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ViewToggle({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.info.color : AppColors.muted.color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.borderSolid.color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppColors.fgDim.color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onSwitchToBrowser;
  const _EmptyState({required this.onSwitchToBrowser});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.cloud_off, size: 48, color: AppColors.fgDim.color),
          const SizedBox(height: 12),
          Text(
            '暂无用量数据',
            style: TextStyle(color: AppColors.fgMuted.color, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '请先在浏览器中登录 Google 账号，然后点击「刷新全部用量」',
            style: TextStyle(color: AppColors.fgDim.color, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onSwitchToBrowser,
            child: const Text('打开浏览器'),
          ),
        ],
      ),
    );
  }
}
