import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/widgets/coin_display.dart';
import '../logic/chess_service.dart';

class ChessLobbyScreen extends ConsumerStatefulWidget {
  const ChessLobbyScreen({super.key});

  @override
  ConsumerState<ChessLobbyScreen> createState() => _ChessLobbyScreenState();
}

class _ChessLobbyScreenState extends ConsumerState<ChessLobbyScreen> {
  bool    _searching = false;
  String? _lobbyId;
  Timer?  _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (_lobbyId != null) {
      ref.read(chessServiceProvider).leaveLobby(_lobbyId!);
    }
    super.dispose();
  }

  Future<void> _play() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    if (user.coinBalance < 400) {
      _showSnack('You need 400 coins to play.', isError: true);
      return;
    }
    setState(() => _searching = true);
    try {
      final result = await ref.read(chessServiceProvider).createOrJoinLobby(user.username);
      if (!mounted) return;
      if (result.startsWith('game:')) {
        context.go('/chess/game/${result.split(':')[1]}');
      } else {
        final lid = result.split(':')[1];
        setState(() => _lobbyId = lid);
        _watchLobby(lid, user.uid);
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

  void _watchLobby(String lobbyId, String uid) {
    final db = FirebaseFirestore.instance;

    // Watch the lobby doc — when deleted, game has started
    db.collection('chess_lobbies').doc(lobbyId).snapshots().listen((snap) async {
      if (!snap.exists && mounted) {
        await _findAndNavigateToGame(db, uid);
      }
    });

    // Also poll every 3 seconds as a fallback in case the snapshot is slow
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final snap = await db.collection('chess_lobbies').doc(lobbyId).get();
      if (!snap.exists && mounted) {
        _pollTimer?.cancel();
        await _findAndNavigateToGame(db, uid);
      }
    });
  }

  Future<void> _findAndNavigateToGame(FirebaseFirestore db, String uid) async {
    try {
      // Query both white and black without orderBy to avoid index requirement
      final q1 = await db.collection('chess_games')
          .where('whitePlayerId', isEqualTo: uid)
          .limit(5)
          .get();
      final q2 = await db.collection('chess_games')
          .where('blackPlayerId', isEqualTo: uid)
          .limit(5)
          .get();

      QueryDocumentSnapshot? best;
      for (final doc in [...q1.docs, ...q2.docs]) {
        if (best == null) { best = doc; continue; }
        final t  = DateTime.parse(doc['createdAt'] as String);
        final bt = DateTime.parse(best['createdAt'] as String);
        if (t.isAfter(bt)) best = doc;
      }

      if (best != null && mounted) {
        _pollTimer?.cancel();
        setState(() { _lobbyId = null; _searching = false; });
        context.go('/chess/game/${best.id}');
      }
    } catch (e) {
      debugPrint('Error finding game: $e');
    }
  }

  Future<void> _cancel() async {
    if (_lobbyId != null) {
      await ref.read(chessServiceProvider).leaveLobby(_lobbyId!);
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
        child: SafeArea(
          child: Column(children: [
            _header(user),
            Expanded(child: _body(user)),
          ]),
        ),
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
      const Text('♟  Chess', style: TextStyle(
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
      gradient: AppColors.gradientPurple,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('♟  CHESS', style: TextStyle(
          fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 2)),
      const SizedBox(height: 6),
      const Text('1v1 · 7 Minute Timer · Full Rules',
          style: TextStyle(color: Colors.white70, fontSize: 13)),
      const SizedBox(height: 20),
      Row(children: [
        _chip('Entry', '400 🪙'),
        const SizedBox(width: 10),
        _chip('Win',   '700 🪙'),
        const SizedBox(width: 10),
        _chip('2nd',   '—'),
      ]),
      const SizedBox(height: 12),
      const Row(children: [
        Icon(Icons.bolt, color: Colors.amber, size: 14),
        SizedBox(width: 4),
        Text('Draw → Armageddon (Black wins draw odds)',
            style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
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
      Text(val,   style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
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
        '400 coins will be deducted from both players when the game starts.',
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

  Widget _waitingView() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const SizedBox(width: 72, height: 72,
          child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 3))
          .animate(onPlay: (c) => c.repeat()).rotate(duration: 2.seconds),
      const SizedBox(height: 24),
      const Text('Waiting for opponent…', style: TextStyle(
          fontSize: 20, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      const Text('You\'ll be taken to the board automatically.',
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

  Widget _openLobbies() {
    final lobbies = ref.watch(chessLobbyProvider).valueOrNull ?? [];
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
  final ChessLobby lobby;
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
      const CircleAvatar(
          radius: 18, backgroundColor: AppColors.purple,
          child: Icon(Icons.person, color: Colors.white, size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(lobby.creatorName, style: const TextStyle(
            fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const Text('Waiting for opponent…',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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