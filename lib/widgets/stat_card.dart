import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../utils/color_ext.dart';

/// 概览统计卡片 - 对应原 StatCard
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String colorHex;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.colorHex,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.card.color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.borderSolid.color),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.fgDim.color,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: colorHex.color,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
