import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/widgets/coin_display.dart';
import '../logic/whot_service.dart';

class WhotLobbyScreen extends ConsumerStatefulWidget {
  const WhotLobbyScreen({super.key});
  @override
  ConsumerState<WhotLobbyScreen> createState() => _WhotLobbyScreenState();
}

class _WhotLobbyScreenState extends ConsumerState<WhotLobbyScreen> {
  bool    _searching = false;
  String? _lobbyId;

  @override
  void dispose() {
    if (_lobbyId != null) {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user != null) {
        ref.read(whotServiceProvider).leaveLobby(_lobbyId!, user.username);
      }
    }
    super.dispose();
  }

  Future<void> _play() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    if (user.coinBalance < 400) {
      _showSnack('You need 400 coins.', isError: true); return;
    }
    setState(() => _searching = true);
    try {
      final result = await ref.read(whotServiceProvider).joinOrCreate(user.username);
      if (!mounted) return;
      if (result.startsWith('game:')) {
        context.go('/whot/game/${result.split(':')[1]}');
      } else {
        final lid = result.split(':')[1];
        setState(() => _lobbyId = lid);
        _watchLobby(lid);
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('failed-precondition') || msg.contains('index')) {
          msg = 'Database index not ready. Please wait a moment and try again.';
        } else if (msg.contains('permission-denied')) {
          msg = 'Permission denied. Check Firestore rules.';
        } else if (msg.contains('Insufficient')) {
          msg = 'Insufficient coins! You need 400 coins to play.';
        } else if (msg.contains('TimeoutException') || msg.contains('timeout')) {
          msg = 'Connection timed out. Please check your internet and try again.';
        } else {
          msg = msg.replaceAll('Exception: ', '');
        }
        _showSnack(msg, isError: true);
        setState(() { _searching = false; _lobbyId = null; });
      }
    }
  }

  void _watchLobby(String lobbyId) {
    FirebaseFirestore.instance
        .collection('whot_lobbies')
        .doc(lobbyId)
        .snapshots()
        .listen((snap) async {
      if (!snap.exists && mounted) {
        // Lobby converted to game
        final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
        final games = await FirebaseFirestore.instance
            .collection('whot_games')
            .orderBy('createdAt', descending: true)
            .limit(10)
            .get();

        for (final doc in games.docs) {
          final players = doc['players'] as List;
          if (players.any((p) => (p as Map)['uid'] == uid)) {
            if (mounted) {
              context.go('/whot/game/${doc.id}');
              setState(() { _lobbyId = null; _searching = false; });
            }
            return;
          }
        }
      }
    });
  }

  Future<void> _cancel() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (_lobbyId != null && user != null) {
      await ref.read(whotServiceProvider).leaveLobby(_lobbyId!, user.username);
    }
    if (mounted) setState(() { _searching = false; _lobbyId = null; });
  }

  void _showSnack(String msg, {bool isError = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
      ));

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
        child: SafeArea(child: Column(children: [
          _header(user),
          Expanded(child: _body(user)),
        ])),
      ),
    );
  }

  Widget _header(user) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    child: Row(children: [
      IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
        onPressed: () => context.go('/home'),
      ),
      const Text('🃏  Whot', style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const Spacer(),
      if (user != null) CoinDisplay(balance: user.coinBalance),
      const SizedBox(width: 12),
    ]),
  );

  Widget _body(user) {
    if (_searching && _lobbyId != null) return _waitingView();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        _gameCard(),
        const SizedBox(height: 20),
        _warningBanner(),
        const SizedBox(height: 20),
        _playBtn(user),
        const SizedBox(height: 32),
        _openLobbies(),
      ]),
    );
  }

  Widget _gameCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: AppColors.gradientTeal,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('🃏  WHOT', style: TextStyle(
          fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 2)),
      const SizedBox(height: 6),
      const Text('4 Players · 7 Minute Timer · Landscape',
          style: TextStyle(color: Colors.white70, fontSize: 13)),
      const SizedBox(height: 20),
      Row(children: [
        _chip('Entry', '400 🪙'),
        const SizedBox(width: 10),
        _chip('1st',   '1000 🪙'),
        const SizedBox(width: 10),
        _chip('2nd',   '300 🪙'),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: [
        '1 - Hold On', '2 - Pick Two', '5 - Pick Three',
        '8 - Suspension', '14 - General Market', '20 - Whot!',
      ].map((s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 9)),
      )).toList()),
    ]),
  ).animate().fadeIn().slideY(begin: 0.15);

  Widget _chip(String label, String val) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      const SizedBox(height: 2),
      Text(val, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _warningBanner() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.warning.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.warning.withOpacity(0.35)),
    ),
    child: const Row(children: [
      Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
      SizedBox(width: 10),
      Expanded(child: Text(
        '400 coins will be deducted from all 4 players once the game starts. '
        'The game begins automatically when 4 players join.',
        style: TextStyle(color: AppColors.warning, fontSize: 12),
      )),
    ]),
  ).animate().fadeIn(delay: 150.ms);

  Widget _playBtn(user) {
    final ok = (user?.coinBalance ?? 0) >= 400;
    return SizedBox(
      width: double.infinity, height: 56,
      child: ElevatedButton(
        onPressed: ok && !_searching ? _play : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: ok ? AppColors.teal : AppColors.textMuted,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _searching
            ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Searching...', style: TextStyle(fontSize: 16)),
              ])
            : Text(ok ? 'PLAY (400 🪙)' : 'Insufficient Coins',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                    letterSpacing: 1, color: AppColors.bg0)),
      ),
    ).animate().fadeIn(delay: 250.ms);
  }

  Widget _waitingView() {
    final lobbies = ref.watch(whotLobbyProvider).valueOrNull ?? [];
    final myLobby = _lobbyId != null
        ? lobbies.where((l) => l.lobbyId == _lobbyId).firstOrNull : null;
    final count = myLobby?.players.length ?? 1;

    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        // Player slots
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(4, (i) =>
          Container(
            margin: const EdgeInsets.all(6),
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: i < count ? AppColors.teal.withOpacity(0.2) : AppColors.bg2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: i < count ? AppColors.teal : AppColors.cardBorder,
                width: i < count ? 2 : 1,
              ),
            ),
            child: Center(child: i < count
                ? const Icon(Icons.person, color: AppColors.teal, size: 28)
                : const Icon(Icons.person_outline, color: AppColors.textMuted, size: 28)),
          ),
        )),
        const SizedBox(height: 16),
        Text('$count / 4 players joined', style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Waiting for more players…',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 32),
        OutlinedButton.icon(
          onPressed: _cancel,
          icon: const Icon(Icons.close, color: AppColors.danger),
          label: const Text('Leave Lobby', style: TextStyle(color: AppColors.danger)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
        ),
      ]),
    );
  }

  Widget _openLobbies() {
    final lobbies = ref.watch(whotLobbyProvider).valueOrNull ?? [];
    if (lobbies.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Open Lobbies', style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        ...lobbies.map((l) => _LobbyTile(l)
            .animate().fadeIn().slideX(begin: 0.1)),
      ],
    );
  }
}

class _LobbyTile extends StatelessWidget {
  final WhotLobby lobby;
  const _LobbyTile(this.lobby);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.bg2,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Row(children: [
      Stack(children: List.generate(lobby.players.length, (i) => Transform.translate(
        offset: Offset(i * 14.0, 0),
        child: const CircleAvatar(
            radius: 14, backgroundColor: AppColors.teal,
            child: Icon(Icons.person, color: Colors.white, size: 14)),
      ))),
      SizedBox(width: lobby.players.length * 14.0 + 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(lobby.players.map((p) => p.name.split(' ').first).join(', '),
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                fontSize: 12)),
        Text('${lobby.players.length}/4 players',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('OPEN', style: TextStyle(
            color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    ]),
  );
}