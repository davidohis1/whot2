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

                  // ── Chess ────────────────────────────────────────────────
                  _GameCard(
                    title:    'Chess',
                    subtitle: '1v1 · 7 min · Full rules',
                    emoji:    '♟',
                    gradient: AppColors.gradientPurple,
                    entry:    400,
                    win:      700,
                    features: [
                      'Castling', 'En Passant', 'Promotion', 'Armageddon Draw'
                    ],
                    onPlay: () => context.go('/chess/lobby'),
                  ).animate().fadeIn().slideX(begin: -0.1),
                  const SizedBox(height: 14),

                  // ── Whot ─────────────────────────────────────────────────
                  _GameCard(
                    title:    'Whot',
                    subtitle: '4 Players · 7 min timer',
                    emoji:    '🃏',
                    gradient: AppColors.gradientTeal,
                    entry:    400,
                    win:      1000,
                    features: [
                      'Pick 2 / 3', 'General Market', 'Suspension', 'Last Card!'
                    ],
                    onPlay: () => _showWhotModeSheet(context),
                  ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.1),
                  const SizedBox(height: 14),

                  // ── Ludo ─────────────────────────────────────────────────
                  _GameCard(
                    title:    'Ludo',
                    subtitle: '2 or 4 Players · 7 min · 10s per move',
                    emoji:    '🎲',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7B2D00), Color(0xFFD4500A)],
                      begin:  Alignment.topLeft,
                      end:    Alignment.bottomRight,
                    ),
                    entry:    400,
                    win:      1100,
                    features: [
                      'Capture +15', 'Home +25', 'Blocks', 'Safe Zones'
                    ],
                    onPlay: () => _showLudoModeSheet(context),
                  ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),

                  const SizedBox(height: 24),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Ludo mode bottom-sheet ─────────────────────────────────────────────────

  void _showLudoModeSheet(BuildContext context) {
    showModalBottomSheet(
      context:         context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _LudoModeSheet(),
    );
  }

  void _showWhotModeSheet(BuildContext context) {
  showModalBottomSheet(
    context:            context,
    backgroundColor:    Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _WhotModeSheet(),
  );
}

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header(BuildContext context, WidgetRef ref, user) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Welcome back,', style: const TextStyle(
            color: AppColors.textSecondary, fontSize: 13)),
        Text(user?.username ?? '—', style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 20,
            fontWeight: FontWeight.w700)),
      ]),
      const Spacer(),
      if (user != null)
        GestureDetector(
          onTap: () => context.go('/wallet'),
          child: CoinDisplay(balance: user.coinBalance),
        ),
      const SizedBox(width: 8),
      IconButton(
        icon:      const Icon(Icons.logout, color: AppColors.textSecondary),
        onPressed: () => ref.read(authServiceProvider).logout(),
      ),
    ]),
  );

  Widget _statsRow(user) => Container(
    margin:  const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color:  AppColors.bg2,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Row(children: [
      _stat('Chess W', '${user?.chessWins ?? 0}',  AppColors.teal),
      _divider(),
      _stat('Chess L', '${user?.chessLosses ?? 0}', AppColors.danger),
      _divider(),
      _stat('Whot W',  '${user?.whotWins ?? 0}',   AppColors.gold),
      _divider(),
      _stat('Whot L',  '${user?.whotLosses ?? 0}',  AppColors.danger),
    ]),
  );

  Widget _stat(String label, String val, Color col) => Expanded(
    child: Column(children: [
      Text(val, style: TextStyle(
          color: col, fontSize: 18, fontWeight: FontWeight.w700)),
      Text(label, style: const TextStyle(
          color: AppColors.textMuted, fontSize: 10)),
    ]),
  );

  Widget _divider() =>
      Container(width: 1, height: 28, color: AppColors.divider);

  Widget _sectionTitle(String t) => Align(
    alignment: Alignment.centerLeft,
    child: Text(t, style: const TextStyle(
        color:       AppColors.textSecondary,
        fontSize:    12,
        letterSpacing: 1.5,
        fontWeight:  FontWeight.w700)),
  );
}

// ── Ludo mode selection bottom-sheet ─────────────────────────────────────────

class _LudoModeSheet extends StatelessWidget {
  const _LudoModeSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width:  40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color:        Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          const Text(
            '🎲  Choose Mode',
            style: TextStyle(
              color:      Colors.white,
              fontSize:   22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select how many players you want to compete against',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // 2-player card
          _ModeCard(
            icon:     '⚔️',
            title:    '2 Players',
            subtitle: '1v1 head-to-head',
            details:  'Red vs Yellow · Opposite corners',
            entry:    400,
            prize:    '700 🪙',
            prizeLabel: 'Winner gets',
            color:    const Color(0xFFE53935),
            onTap: () {
              Navigator.pop(context);
              context.go('/ludo/lobby', extra: 2);
            },
          ),
          const SizedBox(height: 14),

          // 4-player card
          _ModeCard(
            icon:     '🏆',
            title:    '4 Players',
            subtitle: 'Full 4-way battle',
            details:  'Red · Green · Yellow · Blue',
            entry:    400,
            prize:    '1100 🪙',
            prizeLabel: '1st place gets',
            color:    const Color(0xFFD4500A),
            onTap: () {
              Navigator.pop(context);
              context.go('/ludo/lobby', extra: 4);
            },
          ),

          const SizedBox(height: 20),

          // Cancel
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white38, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhotModeSheet extends StatelessWidget {
  const _WhotModeSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color:        Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const Text('🃏  Choose Mode', style: TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Select how many players you want to compete against',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 24),

          _ModeCard(
            icon:       '⚔️',
            title:      '2 Players',
            subtitle:   '1v1 head-to-head',
            details:    'Winner takes all',
            entry:      400,
            prize:      '700 🪙',
            prizeLabel: 'Winner gets',
            color:      const Color(0xFF00897B),
            onTap: () {
              Navigator.pop(context);
              context.go('/whot/lobby', extra: 2);
            },
          ),
          const SizedBox(height: 14),

          _ModeCard(
            icon:       '🏆',
            title:      '4 Players',
            subtitle:   'Full 4-way battle',
            details:    '1st: 1000 🪙  ·  2nd: 300 🪙',
            entry:      400,
            prize:      '1000 🪙',
            prizeLabel: '1st place gets',
            color:      const Color(0xFF00695C),
            onTap: () {
              Navigator.pop(context);
              context.go('/whot/lobby', extra: 4);
            },
          ),

          const SizedBox(height: 20),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white38, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String     icon;
  final String     title;
  final String     subtitle;
  final String     details;
  final int        entry;
  final String     prize;
  final String     prizeLabel;
  final Color      color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.details,
    required this.entry,
    required this.prize,
    required this.prizeLabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.85), color.withOpacity(0.4)],
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color:      color.withOpacity(0.25),
              blurRadius: 14,
              offset:     const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            // Icon
            Container(
              width:  60,
              height: 60,
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(icon,
                    style: const TextStyle(fontSize: 30)),
              ),
            ),
            const SizedBox(width: 16),

            // Text info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(
                      color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w700)),
                  Text(subtitle, style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(details, style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 11)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _pill('Entry: $entry 🪙'),
                    const SizedBox(width: 6),
                    _pill('$prizeLabel: $prize'),
                  ]),
                ],
              ),
            ),

            const Icon(Icons.arrow_forward_ios,
                color: Colors.white60, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _pill(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color:        Colors.black26,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(t,
        style: const TextStyle(
            color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
  );
}

// ── Game card (unchanged from original) ───────────────────────────────────────

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
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.gradient,
    required this.entry,
    required this.win,
    required this.features,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient:     gradient,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color:      gradient.colors.first.withOpacity(0.3),
          blurRadius: 16,
          offset:     const Offset(0, 6),
        )
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:        onPlay,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(
                      color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.w700)),
                  Text(subtitle, style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: features
                        .map((f) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:        Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(f,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 9)),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    _pill('Entry: $entry 🪙'),
                    const SizedBox(width: 6),
                    _pill('Win: $win 🪙'),
                  ]),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white60, size: 16),
          ]),
        ),
      ),
    ),
  );

  Widget _pill(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color:        Colors.black26,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(t,
        style: const TextStyle(
            color: Colors.white, fontSize: 10,
            fontWeight: FontWeight.w600)),
  );
}