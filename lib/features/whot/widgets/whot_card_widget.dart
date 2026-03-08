import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/whot_models.dart';

class WhotCardWidget extends StatelessWidget {
  final WhotCard card;
  final double   size;
  final bool     selected;

  const WhotCardWidget({
    super.key,
    required this.card,
    this.size     = 60,
    this.selected = false,
  });

  Color get _shapeColor {
    const map = {
      WhotShape.circle:   AppColors.circle,
      WhotShape.triangle: AppColors.triangle,
      WhotShape.cross:    AppColors.cross,
      WhotShape.square:   AppColors.square,
      WhotShape.star:     AppColors.star,
      WhotShape.whot:     AppColors.whotCard,
    };
    return map[card.shape] ?? Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final w = size;
    final h = size * 1.4;
    final col = _shapeColor;

    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(w * 0.12),
        border: Border.all(
          color: selected ? AppColors.teal : col.withOpacity(0.4),
          width: selected ? 3 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: col.withOpacity(selected ? 0.5 : 0.25),
            blurRadius: selected ? 12 : 5,
            spreadRadius: selected ? 2 : 0,
          ),
        ],
      ),
      child: card.isWhot ? _buildWhotCard(w, h) : _buildNormalCard(w, h, col),
    );
  }

  Widget _buildNormalCard(double w, double h, Color col) {
    return Stack(children: [
      // Top-left number
      Positioned(top: w * 0.06, left: w * 0.08,
        child: Text('${card.number}', style: TextStyle(
          fontSize: w * 0.22, color: col, fontWeight: FontWeight.w700, height: 1))),
      // Top-left shape
      Positioned(top: w * 0.24, left: w * 0.08,
        child: Text(card.shapeEmoji, style: TextStyle(fontSize: w * 0.18))),

      // Centre symbol
      Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(card.shapeEmoji, style: TextStyle(fontSize: w * 0.38)),
        Text('${card.number}', style: TextStyle(
            fontSize: w * 0.26, color: col, fontWeight: FontWeight.w900)),
      ])),

      // Bottom-right (rotated)
      Positioned(bottom: w * 0.06, right: w * 0.08,
        child: Transform.rotate(angle: 3.14159,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${card.number}', style: TextStyle(
                fontSize: w * 0.22, color: col, fontWeight: FontWeight.w700, height: 1)),
            Text(card.shapeEmoji, style: TextStyle(fontSize: w * 0.18)),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildWhotCard(double w, double h) {
    return Container(
      decoration: BoxDecoration(
        gradient: const SweepGradient(colors: [
          AppColors.circle, AppColors.triangle, AppColors.cross,
          AppColors.square, AppColors.star, AppColors.circle,
        ]),
        borderRadius: BorderRadius.circular(w * 0.12),
      ),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(w * 0.1),
        ),
        child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('🌟', style: TextStyle(fontSize: w * 0.38)),
          Text('WHOT', style: TextStyle(
            fontSize: w * 0.2, color: AppColors.whotCard,
            fontWeight: FontWeight.w900, letterSpacing: 1)),
          Text('20', style: TextStyle(
            fontSize: w * 0.22, color: AppColors.whotCard, fontWeight: FontWeight.w700)),
        ])),
      ),
    );
  }
}