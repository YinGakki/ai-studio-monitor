import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/colors.dart';
import '../utils/color_ext.dart';
import 'breathing_dot.dart';
import 'color_block.dart';

/// 模型可用性卡片 - 对应原 ModelAvailCard
/// 标题行(呼吸灯+名称+汇总+刷新按钮) + 项目色块网格
class ModelAvailCard extends StatelessWidget {
  final String title;
  final String colorHex;
  final List<BlockData> blocks;
  final String summaryText;
  final int? totalRpdCur;
  final int? totalRpdMax;
  final VoidCallback? onRefresh;

  const ModelAvailCard({
    super.key,
    required this.title,
    required this.colorHex,
    required this.blocks,
    this.summaryText = '',
    this.totalRpdCur,
    this.totalRpdMax,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.card.color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSolid.color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              BreathingDot(rpdCur: totalRpdCur, rpdMax: totalRpdMax, size: 14),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.fg.color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (totalRpdCur != null && totalRpdMax != null)
                BreathingDot(rpdCur: totalRpdCur, rpdMax: totalRpdMax, size: 12),
              if (summaryText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    summaryText,
                    style: TextStyle(
                      color: AppColors.fgMuted.color,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              if (onRefresh != null)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                  color: AppColors.fgMuted.color,
                  tooltip: '刷新此卡片',
                  onPressed: onRefresh,
                ),
            ],
          ),
          const SizedBox(height: 4),
          // 色块网格 - 横向滚动
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: blocks
                  .map((b) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: ColorBlock(block: b),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
