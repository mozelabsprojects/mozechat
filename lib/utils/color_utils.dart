import 'package:flutter/material.dart';

Color getContrastColor(Color color) {
  if (color.a < 0.5) return Colors.white;
  return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}
