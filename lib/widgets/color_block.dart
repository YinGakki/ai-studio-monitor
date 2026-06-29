import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/colors.dart';
import '../utils/color_ext.dart';
import 'breathing_dot.dart';

/// 单个色块单元格 - 对应原 ModelAvailCard.set_blocks 中的 cell
class ColorBlock extends StatelessWidget {
  final BlockData block;

  const ColorBlock({super.key, required this.block});

  @override
  Widget build(BuildContext context) {
    final hasData = block.rpd != null && block.rpdMax != null;
    const fs = 1.0; // 字体缩放因子

    String bg;
    String fg;
    if (hasData) {
      final rpd = block.rpd!;
      final max = block.rpdMax!;
      final ratio = max > 0 ? rpd / max : 0.0;
      if (rpd >= max) {
        bg = AppColors.blockRed;
        fg = AppColors.destructive;
      } else if (ratio < 0.5) {
        bg = AppColors.blockGreen;
        fg = AppColors.success;
      } else {
        bg = AppColors.blockYellow;
        fg = AppColors.warning;
      }
    } else {
      bg = AppColors.muted;
      fg = AppColors.fgDim;
    }

    // 边框：changed/glow 高亮
    Border? border;
    if (block.glow && block.changed) {
      border = Border.all(color: '#ffcc33'.color, width: 2);
    } else if (block.glow) {
      border = Border.all(color: '#22c55e'.color, width: 2);
    } else if (block.changed) {
      border = Border.all(color: '#ffcc33'.color, width: 2);
    } else {
      border = Border.all(color: AppColors.borderSolid.color.withValues(alpha: 0.3), width: 1);
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 56, minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: BoxDecoration(
        color: bg.color,
        borderRadius: BorderRadius.circular(4),
        border: border,
        boxShadow: (block.glow || block.changed)
            ? [
                BoxShadow(
                  color: (block.glow ? '#22c55e' : '#ffcc33').color
                      .withValues(alpha: 0.45),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  block.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.fgDim.color,
                    fontSize: 8 * fs,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              BreathingDot(
                rpdCur: block.rpd,
                rpdMax: block.rpdMax,
                size: 10,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            hasData ? '${block.rpd}/${block.rpdMax}' : '—',
            style: TextStyle(
              color: fg.color,
              fontSize: 10 * fs,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
