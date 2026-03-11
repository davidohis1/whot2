import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/widgets/coin_display.dart';
import '../logic/ludo_service.dart';
import '../models/ludo_models.dart';

class LudoLobbyScreen extends ConsumerStatefulWidget {
  /// Pass mode=2 for 2-player, mode=4 (default) for 4-player.
  final int modeArg;

  const LudoLobbyScreen({super.key, this.modeArg = 4});

  @override
  ConsumerState<LudoLobbyScreen> createState() => _LudoLobbyScreenState();
}

class _LudoLobbyScreenState extends ConsumerState<LudoLobbyScreen> {
  late LudoGameMode _mode;

  bool    _searching = false;
  String? _lobbyId;
  Timer?  _pollTimer;

  // Color names/values differ per mode
  static const _4pColorNames = ['Red', 'Green', 'Yellow', 'Blue'];
  static const _2pColorNames = ['Red', 'Yellow'];
  static const _colorValues  = [
    Color(0xFFE53935),
    Color(0xFF43A047),
    Color(0xFFFDD835),
    Color(0xFF1E88E5),
  ];

  @override
  void initState() {
    super.initState();
    _mode = widget.modeArg == 2
        ? LudoGameMode.twoPlayer
        : LudoGameMode.fourPlayer;
  }

  // ── Getters ───────────────────────────────────────────────────────────────

  int get _required       => _mode == LudoGameMode.twoPlayer ? 2 : 4;
  int get _entry          => 400;
  String get _prizeText   =>
      _mode == LudoGameMode.twoPlayer ? '700 🪙 winner' : '1100 🪙 1st · 200 🪙 2nd';

  List<String> get _colorNames =>
      _mode == LudoGameMode.twoPlayer ? _2pColorNames : _4pColorNames;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (_lobbyId != null) {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user != null) {
        ref.read(ludoServiceProvider).leaveLobby(_lobbyId!, user.username);
      }
    }
    super.dispose();
  }

  // ── Match-making ──────────────────────────────────────────────────────────

  Future<void> _play() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    if (user.coinBalance < _entry) {
      _showSnack('You need $_entry coins to play.', isError: true);
      return;
    }
    setState(() => _searching = true);
    try {
      final result =
          await ref.read(ludoServiceProvider).joinOrCreate(user.username, _mode);
      if (!mounted) return;
      if (result.startsWith('game:')) {
        context.go('/ludo/game/${result.split(':')[1]}');
      } else {
        final lid = result.split(':')[1];
        setState(() => _lobbyId = lid);
        _watchLobby(lid);
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString().replaceAll('Exception: ', '');
        if (msg.contains('TimeoutException') || msg.contains('timeout')) {
          msg = 'Connection timed out. Check your internet.';
        }
        _showSnack(msg, isError: true);
        setState(() {
          _searching = false;
          _lobbyId   = null;
        });
      }
    }
  }

  void _watchLobby(String lobbyId) {
    final db  = FirebaseFirestore.instance;
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';

    db.collection('ludo_lobbies').doc(lobbyId).snapshots().listen((snap) async {
      if (!snap.exists && mounted) {
        _pollTimer?.cancel();
        await _findAndNavigate(db, uid);
      }
    });

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final snap = await db.collection('ludo_lobbies').doc(lobbyId).get();
      if (!snap.exists && mounted) {
        _pollTimer?.cancel();
        await _findAndNavigate(db, uid);
      }
    });
  }

  Future<void> _findAndNavigate(FirebaseFirestore db, String uid) async {
    try {
      final games = await db
          .collection('ludo_games')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();
      for (final doc in games.docs) {
        final players = doc['players'] as List;
        if (players.any((p) => (p as Map)['uid'] == uid)) {
          if (mounted) {
            setState(() {
              _lobbyId   = null;
              _searching = false;
            });
            context.go('/ludo/game/${doc.id}');
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Find game error: $e');
    }
  }

  Future<void> _cancel() async {
    _pollTimer?.cancel();
    final user = ref.read(currentUserProvider).valueOrNull;
    if (_lobbyId != null && user != null) {
      await ref.read(ludoServiceProvider).leaveLobby(_lobbyId!, user.username);
    }
    if (mounted) {
      setState(() {
        _searching = false;
        _lobbyId   = null;
      });
    }
  }

  void _showSnack(String msg, {bool isError = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         Text(msg),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
      ));

  // ── Build ─────────────────────────────────────────────────────────────────

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

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _header(user) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    child: Row(children: [
      IconButton(
        icon:      const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
        onPressed: () => context.go('/home'),
      ),
      Text(
        '🎲  Ludo — ${_mode == LudoGameMode.twoPlayer ? "2 Players" : "4 Players"}',
        style: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary),
      ),
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

  Widget _gameCard() {
    final is2p = _mode == LudoGameMode.twoPlayer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B2D00), Color(0xFFD4500A)],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:      const Color(0xFFD4500A).withOpacity(0.4),
            blurRadius: 20,
            offset:     const Offset(0, 6),
          )
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          is2p ? '⚔️  LUDO 1v1' : '🏆  LUDO 4-PLAYER',
          style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: 1.5),
        ),
        const SizedBox(height: 6),
        Text(
          is2p
              ? '2 Players · 7 Min Timer · 10s Per Move'
              : '4 Players · 7 Min Timer · 10s Per Move',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Row(children: [
          _chip('Entry', '$_entry 🪙'),
          const SizedBox(width: 10),
          if (is2p) ...[
            _chip('Winner', '700 🪙'),
          ] else ...[
            _chip('1st',  '1100 🪙'),
            const SizedBox(width: 10),
            _chip('2nd',  '200 🪙'),
          ],
        ]),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8, runSpacing: 6,
          children: [
            '🎯 +dice pts per move',
            '⚔ +15 for capture',
            '🏠 +25 token home',
            '💀 -roll pts if captured',
          ].map((s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(s,
                style: const TextStyle(color: Colors.white, fontSize: 10)),
          )).toList(),
        ),
      ]),
    ).animate().fadeIn().slideY(begin: 0.15);
  }

  Widget _chip(String label, String val) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color:        Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      const SizedBox(height: 2),
      Text(val, style: const TextStyle(
          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _warningBanner() {
    final is2p = _mode == LudoGameMode.twoPlayer;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: AppColors.warning.withOpacity(0.35)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded,
            color: AppColors.warning, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            is2p
                ? '400 coins deducted when game starts. '
                  'Winner takes 700 coins. Score decides winner if timer runs out.'
                : '400 coins deducted from all 4 players when game starts. '
                  'Winner determined by score if timer runs out.',
            style: const TextStyle(color: AppColors.warning, fontSize: 12),
          ),
        ),
      ]),
    ).animate().fadeIn(delay: 150.ms);
  }

  Widget _playBtn(user) {
    final ok = (user?.coinBalance ?? 0) >= _entry;
    return SizedBox(
      width: double.infinity, height: 56,
      child: ElevatedButton(
        onPressed: ok && !_searching ? _play : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor:     Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          padding: EdgeInsets.zero,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: ok
                ? const LinearGradient(
                    colors: [Color(0xFFD4500A), Color(0xFF7B2D00)])
                : null,
            color:        ok ? null : AppColors.textMuted,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            alignment: Alignment.center,
            child: _searching
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Searching...', style: TextStyle(
                          fontSize: 16, color: Colors.white)),
                    ],
                  )
                : Text(
                    ok ? 'PLAY ($_entry 🪙)' : 'Insufficient Coins',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        letterSpacing: 1, color: Colors.white),
                  ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 250.ms);
  }

  // ── Waiting view ──────────────────────────────────────────────────────────

  Widget _waitingView() {
    final lobbiesAsync = _mode == LudoGameMode.twoPlayer
        ? ref.watch(ludo2pLobbyProvider)
        : ref.watch(ludoLobbyProvider);
    final lobbies  = lobbiesAsync.valueOrNull ?? [];
    final myLobby  = _lobbyId != null
        ? lobbies.where((l) => l.lobbyId == _lobbyId).firstOrNull
        : null;
    final count    = myLobby?.players.length ?? 1;
    final names    = _colorNames;

    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        // Slot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_required, (i) {
            final filled = i < count;
            final color  = _colorValues[
                _mode == LudoGameMode.twoPlayer
                    ? (i == 0 ? 0 : 2)   // Red index 0, Yellow index 2
                    : i];
            return Container(
              margin: const EdgeInsets.all(8),
              width: 64, height: 64,
              decoration: BoxDecoration(
                color:        filled ? color.withOpacity(0.2) : AppColors.bg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: filled ? color : AppColors.cardBorder,
                  width: filled ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    filled ? Icons.person : Icons.person_outline,
                    color: filled ? color : AppColors.textMuted,
                    size: 26,
                  ),
                  if (filled)
                    Text(names[i],
                        style: TextStyle(
                            color:      color,
                            fontSize:   9,
                            fontWeight: FontWeight.w700)),
                ],
              ),
            );
          }),
        ),

        const SizedBox(height: 16),
        Text('$count / $_required players joined',
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Waiting for more players…',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 32),

        OutlinedButton.icon(
          onPressed: _cancel,
          icon:  const Icon(Icons.close, color: AppColors.danger),
          label: const Text('Leave Lobby',
              style: TextStyle(color: AppColors.danger)),
          style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.danger)),
        ),
      ]),
    );
  }

  // ── Open lobbies list ─────────────────────────────────────────────────────

  Widget _openLobbies() {
    final lobbiesAsync = _mode == LudoGameMode.twoPlayer
        ? ref.watch(ludo2pLobbyProvider)
        : ref.watch(ludoLobbyProvider);
    final lobbies = lobbiesAsync.valueOrNull ?? [];
    if (lobbies.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Open Lobbies', style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700,
          color: AppColors.textSecondary)),
      const SizedBox(height: 10),
      ...lobbies.map((l) =>
          _LobbyTile(lobby: l, mode: _mode)
              .animate()
              .fadeIn()
              .slideX(begin: 0.1)),
    ]);
  }
}

// ── Lobby tile ─────────────────────────────────────────────────────────────────

class _LobbyTile extends StatelessWidget {
  final LudoLobby    lobby;
  final LudoGameMode mode;

  const _LobbyTile({required this.lobby, required this.mode});

  static const _colorValues = [
    Color(0xFFE53935),
    Color(0xFF43A047),
    Color(0xFFFDD835),
    Color(0xFF1E88E5),
  ];

  @override
  Widget build(BuildContext context) => Container(
    margin:  const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color:        AppColors.bg2,
      borderRadius: BorderRadius.circular(12),
      border:       Border.all(color: AppColors.cardBorder),
    ),
    child: Row(children: [
      Stack(children: List.generate(lobby.players.length, (i) =>
        Transform.translate(
          offset: Offset(i * 16.0, 0),
          child: CircleAvatar(
            radius:          14,
            backgroundColor: _colorValues[i % 4],
            child: const Icon(Icons.person, color: Colors.white, size: 14),
          ),
        ),
      )),
      SizedBox(width: lobby.players.length * 16.0 + 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            lobby.players.map((p) => p.name.split(' ').first).join(', '),
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                color:      AppColors.textPrimary,
                fontSize:   12),
          ),
          Text(
            '${lobby.players.length}/${mode == LudoGameMode.twoPlayer ? 2 : 4} players',
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary),
          ),
        ]),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color:        AppColors.success.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('OPEN', style: TextStyle(
            color:      AppColors.success,
            fontSize:   11,
            fontWeight: FontWeight.w700)),
      ),
    ]),
  );
}