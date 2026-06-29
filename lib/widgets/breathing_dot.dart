import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../utils/color_ext.dart';

/// 双层呼吸指示灯 - 对应原 BreathingDot
/// 绿=充足(剩余>50%) / 黄=不足(剩余≤50%) / 红=用完 / 灰=无数据
class BreathingDot extends StatefulWidget {
  final int? rpdCur;
  final int? rpdMax;
  final double size;

  const BreathingDot({
    super.key,
    this.rpdCur,
    this.rpdMax,
    this.size = 14,
  });

  @override
  State<BreathingDot> createState() => _BreathingDotState();
}

class _BreathingDotState extends State<BreathingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  Color get _baseColor {
    final cur = widget.rpdCur;
    final max = widget.rpdMax;
    if (cur == null || max == null || max == 0) return AppColors.fgDim.color;
    if (cur >= max) return AppColors.destructive.color;
    if (cur / max < 0.5) return AppColors.success.color;
    return AppColors.warning.color;
  }

  bool get _breathing {
    final cur = widget.rpdCur;
    final max = widget.rpdMax;
    if (cur == null || max == null || max == 0) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (_breathing) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(BreathingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_breathing && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!_breathing && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _breathing ? (0.5 + 0.5 * sin(_ctrl.value * 2 * pi)) : 0.0;
        final outerAlpha = _breathing ? (50 + 130 * t).round() : 40;
        final innerAlpha = _breathing ? 255 : 140;
        return SizedBox(
          width: s,
          height: s,
          child: CustomPaint(
            painter: _DotPainter(
              baseColor: _baseColor,
              outerAlpha: outerAlpha,
              innerAlpha: innerAlpha,
            ),
          ),
        );
      },
    );
  }
}

class _DotPainter extends CustomPainter {
  final Color baseColor;
  final int outerAlpha;
  final int innerAlpha;

  _DotPainter({
    required this.baseColor,
    required this.outerAlpha,
    required this.innerAlpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerR = size.width / 2 - 1;
    final innerR = max(2.0, size.width * 0.28);

    // 外圈呼吸
    final outerPaint = Paint()
      ..color = baseColor.withValues(alpha: outerAlpha / 255)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), outerR, outerPaint);

    // 中心小圆常亮
    final innerPaint = Paint()
      ..color = baseColor.withValues(alpha: innerAlpha / 255)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), innerR, innerPaint);
  }

  @override
  bool shouldRepaint(_DotPainter oldDelegate) =>
      oldDelegate.outerAlpha != outerAlpha ||
      oldDelegate.innerAlpha != innerAlpha ||
      oldDelegate.baseColor != baseColor;
}
