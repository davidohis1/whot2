import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/chess_models.dart';

class PromotionDialog extends StatelessWidget {
  final PieceColor color;
  final void Function(PieceType) onSelect;

  const PromotionDialog({super.key, required this.color, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final choices = [
      (PieceType.queen,  color == PieceColor.white ? '♕' : '♛'),
      (PieceType.rook,   color == PieceColor.white ? '♖' : '♜'),
      (PieceType.bishop, color == PieceColor.white ? '♗' : '♝'),
      (PieceType.knight, color == PieceColor.white ? '♘' : '♞'),
    ];

    return Container(
      color: AppColors.bg1,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Choose Promotion', style: TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: choices.map((c) => GestureDetector(
            onTap: () => onSelect(c.$1),
            child: Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: AppColors.bg3,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Center(child: Text(c.$2, style: const TextStyle(fontSize: 36))),
            ),
          )).toList(),
        ),
      ]),
    );
  }
}