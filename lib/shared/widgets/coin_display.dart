import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CoinDisplay extends StatelessWidget {
  final int balance;
  const CoinDisplay({super.key, required this.balance});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.gold.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.gold.withOpacity(0.4)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Text('🪙', style: TextStyle(fontSize: 14)),
      const SizedBox(width: 5),
      Text(
        _format(balance),
        style: const TextStyle(
          color: AppColors.gold,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    ]),
  );

  String _format(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
    return '$n';
  }
}