import 'package:flutter/material.dart';

/// "#RRGGBB" → Color
extension HexColor on String {
  Color get color => Color(int.parse(replaceAll('#', ''), radix: 16) + 0xFF000000);
}
