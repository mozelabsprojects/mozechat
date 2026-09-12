import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/color_utils.dart';

class DateDivider extends StatelessWidget {
  final DateTime date;

  const DateDivider({super.key, required this.date});

  String _getDateDividerText(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    if (msgDate == today) return "Today";
    if (msgDate == yesterday) return "Yesterday";

    final diff = today.difference(msgDate).inDays;
    if (diff < 7) {
      return DateFormat('EEEE').format(date); // Monday, Tuesday, etc.
    }

    return DateFormat('dd.MM.yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getDateDividerText(date),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: getContrastColor(cardColor).withValues(alpha: 0.8),
        ),
      ),
    );
  }
}
