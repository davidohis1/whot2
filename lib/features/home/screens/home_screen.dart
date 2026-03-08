import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/widgets/coin_display.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(children: [
              _header(context, ref, user),
              _statsRow(user),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(children: [
                  _sectionTitle('Games'),
                  const SizedBox(height: 12),
                  _GameCard(
                    title: 'Chess',
                    subtitle: '1v1 · 7 min · Full rules',
                    emoji: '♟',
                    gradient: AppColors.gradientPurple,
                    entry: 400, win: 700,
                    features: ['Castling', 'En Passant', 'Promotion', 'Armageddon Draw'],
                    onPlay: () => context.go('/chess/lobby'),
                  ).animate().fadeIn().slideX(begin: -0.1),
                  const SizedBox(height: 14),
                  _GameCard(
                    title: 'Whot',
                    subtitle: '4 Players · 7 min timer',
                    emoji: '🃏',
                    gradient: AppColors.gradientTeal,
                    entry: 400, win: 1000,
                    features: ['Pick 2 / 3', 'General Market', 'Suspension', 'Last Card!'],
                    onPlay: () => context.go('/whot/lobby'),
                  ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.1),
                  const SizedBox(height: 14),
                  _ComingSoonCard(),
                  const SizedBox(height: 24),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, WidgetRef ref, user) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Welcome back,', style: const TextStyle(
            color: AppColors.textSecondary, fontSize: 13)),
        Text(user?.username ?? '—', style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
      ]),
      const Spacer(),
      if (user != null) CoinDisplay(balance: user.coinBalance),
      const SizedBox(width: 8),
      IconButton(
        icon: const Icon(Icons.logout, color: AppColors.textSecondary),
        onPressed: () => ref.read(authServiceProvider).logout(),
      ),
    ]),
  );

  Widget _statsRow(user) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.bg2,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Row(children: [
      _stat('Chess W', '${user?.chessWins ?? 0}', AppColors.teal),
      _divider(),
      _stat('Chess L', '${user?.chessLosses ?? 0}', AppColors.danger),
      _divider(),
      _stat('Whot W',  '${user?.whotWins ?? 0}',  AppColors.gold),
      _divider(),
      _stat('Whot L',  '${user?.whotLosses ?? 0}', AppColors.danger),
    ]),
  );

  Widget _stat(String label, String val, Color col) => Expanded(
    child: Column(children: [
      Text(val, style: TextStyle(color: col, fontSize: 18, fontWeight: FontWeight.w700)),
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
    ]),
  );

  Widget _divider() => Container(width: 1, height: 28, color: AppColors.divider);
  Widget _sectionTitle(String t) => Align(alignment: Alignment.centerLeft,
    child: Text(t, style: const TextStyle(
        color: AppColors.textSecondary, fontSize: 12, letterSpacing: 1.5,
        fontWeight: FontWeight.w700)));
}

class _GameCard extends StatelessWidget {
  final String       title;
  final String       subtitle;
  final String       emoji;
  final LinearGradient gradient;
  final int          entry;
  final int          win;
  final List<String> features;
  final VoidCallback onPlay;

  const _GameCard({
    required this.title, required this.subtitle, required this.emoji,
    required this.gradient, required this.entry, required this.win,
    required this.features, required this.onPlay,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(
          color: gradient.colors.first.withOpacity(0.3),
          blurRadius: 16, offset: const Offset(0, 6))],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPlay,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: features.map((f) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(f, style: const TextStyle(color: Colors.white, fontSize: 9)),
              )).toList()),
              const SizedBox(height: 10),
              Row(children: [
                _pill('Entry: $entry 🪙'),
                const SizedBox(width: 6),
                _pill('Win: $win 🪙'),
              ]),
            ])),
            const Icon(Icons.arrow_forward_ios, color: Colors.white60, size: 16),
          ]),
        ),
      ),
    ),
  );

  Widget _pill(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black26, borderRadius: BorderRadius.circular(8)),
    child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 10,
        fontWeight: FontWeight.w600)),
  );
}

class _ComingSoonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.bg2,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Row(children: [
      const Text('🎲', style: TextStyle(fontSize: 40)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Ludo', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
        const Text('4 Players · Coming Soon',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.textMuted.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('COMING SOON', style: TextStyle(
              color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700,
              letterSpacing: 1)),
        ),
      ])),
    ]),
  );
}