import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/auth_service.dart';
import '../logic/ludo_engine.dart';
import '../logic/ludo_service.dart';
import '../models/ludo_models.dart';
import '../widgets/ludo_board_widget.dart';

class LudoGameScreen extends ConsumerStatefulWidget {
  final String gameId;
  const LudoGameScreen({super.key, required this.gameId});

  @override
  ConsumerState<LudoGameScreen> createState() => _LudoGameScreenState();
}

class _LudoGameScreenState extends ConsumerState<LudoGameScreen>
    with SingleTickerProviderStateMixin {
  // ── Timers ────────────────────────────────────────────────────────────────
  Timer? _globalTimer;

  /// Single per-turn countdown. Counts from 10 → 0 covering BOTH
  /// the roll phase and the move phase. It resets only when the turn
  /// owner changes (or an extra-turn is granted).
  Timer? _turnTimer;
  int    _localTurnSeconds = 10;

  // Tracks whose turn the local timer is currently running for, so we
  // don't restart it on every Firestore snapshot while the same player's
  // turn is active.
  String _timerRunningForUid = '';

  bool _resultShown = false;
  bool _isRolling   = false;

  // ── Dice animation ────────────────────────────────────────────────────────
  late AnimationController _diceController;
  int _displayDice = 1;

  @override
  void initState() {
    super.initState();
    _diceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _globalTimer?.cancel();
    _turnTimer?.cancel();
    _diceController.dispose();
    super.dispose();
  }

  String get _uid => ref.read(authStateProvider).valueOrNull?.uid ?? '';

  // ── Global 7-min timer (only the current-turn player drives it) ───────────
  void _ensureGlobalTimer() {
    if (_globalTimer != null && _globalTimer!.isActive) return;
    _globalTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final g = ref.read(ludoGameProvider(widget.gameId)).valueOrNull;
      if (g == null || g.status == LudoGameStatus.finished) {
        _globalTimer?.cancel();
        return;
      }
      final isMyTurn =
          g.players.indexWhere((p) => p.uid == _uid) == g.currentPlayerIndex;
      if (!isMyTurn) return;

      final newTotal = g.timeLeftSeconds - 1;
      if (newTotal <= 0) {
        _globalTimer?.cancel();
        await ref.read(ludoServiceProvider).endByTimer(widget.gameId, g);
      } else {
        await ref
            .read(ludoServiceProvider)
            .updateGlobalTimer(widget.gameId, newTotal);
      }
    });
  }

  // ── Per-turn 10 s timer ───────────────────────────────────────────────────
  /// Called every time we detect the active turn owner has changed
  /// (or an extra turn was granted to the same player).
  void _startTurnTimer(String ownerUid, LudoGameModel game) {
    _timerRunningForUid = ownerUid;
    _turnTimer?.cancel();
    setState(() => _localTurnSeconds = 10);

    if (ownerUid != _uid) return; // only tick locally for our own turn

    _turnTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      setState(() => _localTurnSeconds--);
      if (_localTurnSeconds <= 0) {
        _turnTimer?.cancel();
        final g = ref.read(ludoGameProvider(widget.gameId)).valueOrNull;
        if (g == null) return;
        await ref.read(ludoServiceProvider).skipTurn(widget.gameId, g);
      }
    });
  }

  // ── Detect turn changes from Firestore snapshots ──────────────────────────
  void _syncTurnTimer(LudoGameModel game) {
    final ownerUid = game.currentPlayer.uid;

    // Start timer when:
    //   • A different player's turn begins, OR
    //   • Same player gets an extra turn (extraTurn flag flipped → diceRolled=false)
    final turnChanged = ownerUid != _timerRunningForUid;
    final extraTurnReset =
        ownerUid == _timerRunningForUid && game.extraTurn && !game.diceRolled;

    if (turnChanged || extraTurnReset) {
      _startTurnTimer(ownerUid, game);
    }
  }

  // ── Roll dice ─────────────────────────────────────────────────────────────
  Future<void> _rollDice(LudoGameModel game) async {
    if (_isRolling) return;
    setState(() => _isRolling = true);

    // Visual dice shuffle
    _diceController.reset();
    _diceController.forward();
    for (int i = 0; i < 8; i++) {
      await Future.delayed(const Duration(milliseconds: 60));
      if (mounted) setState(() => _displayDice = Random().nextInt(6) + 1);
    }

    await ref.read(ludoServiceProvider).rollDice(widget.gameId, game);
    if (mounted) setState(() => _isRolling = false);

    // Timer keeps running — do NOT reset or cancel it here.
    // The player now has whatever seconds remain to also tap a token.
  }

  // ── Move token ────────────────────────────────────────────────────────────
  Future<void> _moveToken(LudoGameModel game, int tokenId) async {
    // Cancel local timer — the service will advance/extra-turn which triggers
    // a new snapshot and _syncTurnTimer will restart it appropriately.
    _turnTimer?.cancel();
    await ref
        .read(ludoServiceProvider)
        .moveToken(widget.gameId, game, tokenId);
  }

  // ── Game end ──────────────────────────────────────────────────────────────
  void _handleGameEnd(LudoGameModel game) {
    if (_resultShown || game.status != LudoGameStatus.finished) return;
    _resultShown = true;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _showResultDialog(game));
  }

  void _showResultDialog(LudoGameModel game) {
    final myRank = game.rankings.indexOf(_uid) + 1;
    final prizes = {1: '+1100 🪙', 2: '+200 🪙', 3: '-400 🪙', 4: '-400 🪙'};
    final rankColors = {
      1: AppColors.gold,
      2: AppColors.teal,
      3: AppColors.danger,
      4: AppColors.danger,
    };
    final labels = {
      1: '🥇 1st Place!',
      2: '🥈 2nd Place',
      3: '🥉 3rd Place',
      4: '4th Place',
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg2,
        title: Text(
          labels[myRank] ?? '',
          style: TextStyle(color: rankColors[myRank], fontSize: 24),
        ),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            prizes[myRank] ?? '',
            style: TextStyle(
              color:      rankColors[myRank],
              fontSize:   22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Divider(color: AppColors.divider, height: 24),
          ...List.generate(game.rankings.length, (i) {
            final uid  = game.rankings[i];
            final p    = game.players.firstWhere(
              (pl) => pl.uid == uid,
              orElse: () => game.players[i],
            );
            final isMe = uid == _uid;
            return Container(
              margin:  const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isMe
                    ? rankColors[i + 1]!.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isMe
                    ? Border.all(color: rankColors[i + 1]!.withOpacity(0.4))
                    : null,
              ),
              child: Row(children: [
                Text(i == 0
                    ? '🥇'
                    : i == 1
                        ? '🥈'
                        : i == 2
                            ? '🥉'
                            : '4️⃣'),
                const SizedBox(width: 8),
                Container(
                  width:  10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _ludoColor(p.color),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  p.name + (isMe ? ' (You)' : ''),
                  style: TextStyle(
                    color:      isMe ? rankColors[i + 1] : AppColors.textPrimary,
                    fontWeight: isMe ? FontWeight.w700 : FontWeight.w400,
                    fontSize:   13,
                  ),
                )),
                Text(
                  '${p.score} pts',
                  style: const TextStyle(
                    color:    AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  prizes[i + 1] ?? '',
                  style: TextStyle(
                    color:      rankColors[i + 1],
                    fontSize:   11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            );
          }),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/home');
            },
            child: const Text('Home',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/ludo/lobby');
            },
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final gameAsync = ref.watch(ludoGameProvider(widget.gameId));

    return gameAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.bg0,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (game) {
        if (game == null) {
          return const Scaffold(
            body: Center(child: Text('Game not found')),
          );
        }

        if (game.status == LudoGameStatus.active) {
          _ensureGlobalTimer();
          _syncTurnTimer(game);
        }
        _handleGameEnd(game);

        final myIdx    = game.players.indexWhere((p) => p.uid == _uid);
        final isMyTurn = myIdx != -1 && myIdx == game.currentPlayerIndex;
        final movable  = isMyTurn && game.diceRolled
            ? LudoEngine.movableTokenIds(game)
            : <int>[];

        return Scaffold(
          backgroundColor: const Color(0xFF1A1A2E),
          body: SafeArea(
            child: Column(children: [
              _topBar(game, isMyTurn),
              const SizedBox(height: 6),
              _scoreRow(game),
              const SizedBox(height: 6),
              Expanded(
                child: Center(
                  child: LudoBoardWidget(
                    game:            game,
                    movableTokenIds: movable,
                    onTokenTap:      (id, _) => _moveToken(game, id),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _bottomBar(game, isMyTurn, movable),
              const SizedBox(height: 8),
            ]),
          ),
        );
      },
    );
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  Widget _topBar(LudoGameModel game, bool isMyTurn) {
    final mins    = game.timeLeftSeconds ~/ 60;
    final secs    = game.timeLeftSeconds % 60;
    final time    = '${mins.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
    final lowGame = game.timeLeftSeconds < 60;
    final lowTurn = _localTurnSeconds <= 3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color:   Colors.black.withOpacity(0.4),
      child: Row(children: [
        IconButton(
          icon:      const Icon(Icons.home, color: Colors.white54, size: 20),
          onPressed: () => context.go('/home'),
        ),
        const Text(
          'LUDO',
          style: TextStyle(
            color:       AppColors.gold,
            fontWeight:  FontWeight.w700,
            fontSize:    16,
            letterSpacing: 2,
          ),
        ),
        const Spacer(),

        // Per-turn countdown — visible only on your turn
        if (isMyTurn)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin:   const EdgeInsets.only(right: 8),
            padding:  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: lowTurn
                  ? AppColors.danger.withOpacity(0.35)
                  : AppColors.teal.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: lowTurn ? AppColors.danger : AppColors.teal),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.timer,
                  size:  12,
                  color: lowTurn ? AppColors.danger : AppColors.teal),
              const SizedBox(width: 3),
              Text(
                '${_localTurnSeconds}s',
                style: TextStyle(
                  color:      lowTurn ? AppColors.danger : AppColors.teal,
                  fontWeight: FontWeight.w700,
                  fontSize:   12,
                ),
              ),
            ]),
          ),

        // Global game timer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: lowGame
                ? AppColors.danger.withOpacity(0.3)
                : Colors.black38,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: lowGame ? AppColors.danger : Colors.white24),
          ),
          child: Text(
            time,
            style: TextStyle(
              color:      lowGame ? AppColors.danger : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize:   13,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _scoreRow(LudoGameModel game) {
    return Container(
      margin:  const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color:        Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: game.players.map((p) {
          final isActive = game.currentPlayerIndex == p.position;
          final isMe     = p.uid == _uid;
          return Expanded(
            child: Container(
              margin:  const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? _ludoColor(p.color).withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: isActive
                    ? Border.all(color: _ludoColor(p.color), width: 1.5)
                    : null,
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width:  8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _ludoColor(p.color),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      p.name.split(' ').first + (isMe ? ' ★' : ''),
                      style: TextStyle(
                        color: isMe ? AppColors.gold : Colors.white70,
                        fontSize:   9,
                        fontWeight: isMe ? FontWeight.w700 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                Text(
                  '${p.score}',
                  style: TextStyle(
                    color:      _ludoColor(p.color),
                    fontSize:   14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _bottomBar(LudoGameModel game, bool isMyTurn, List<int> movable) {
    final dice        = game.diceValue;
    final canRoll     = isMyTurn && !game.diceRolled && !_isRolling;
    final waitingMove = isMyTurn && game.diceRolled;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Left label
          Expanded(
            child: Text(
              isMyTurn ? 'Your Turn!' : "${game.currentPlayer.name}'s turn",
              style: TextStyle(
                color:      isMyTurn ? AppColors.teal : Colors.white54,
                fontWeight: FontWeight.w700,
                fontSize:   13,
              ),
            ),
          ),

          // Dice face
          GestureDetector(
            onTap: canRoll ? () => _rollDice(game) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width:  64,
              height: 64,
              decoration: BoxDecoration(
                color: canRoll
                    ? Colors.white
                    : waitingMove
                        ? Colors.white.withOpacity(0.85)
                        : Colors.grey.shade800,
                borderRadius: BorderRadius.circular(12),
                boxShadow: canRoll
                    ? [
                        BoxShadow(
                          color:       Colors.white.withOpacity(0.4),
                          blurRadius:  12,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: Text(
                  _diceEmoji(dice ?? _displayDice),
                  style: const TextStyle(fontSize: 36),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Right hint
          Expanded(
            child: Text(
              isMyTurn
                  ? (canRoll
                      ? 'Tap dice\nto roll'
                      : movable.isEmpty
                          ? 'No moves\navailable'
                          : 'Tap a token\nto move')
                  : '',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  String _diceEmoji(int val) {
    const faces = ['⚀', '⚁', '⚂', '⚃', '⚄', '⚅'];
    return faces[(val - 1).clamp(0, 5)];
  }

  Color _ludoColor(LudoColor c) {
    switch (c) {
      case LudoColor.red:    return const Color(0xFFE53935);
      case LudoColor.green:  return const Color(0xFF43A047);
      case LudoColor.yellow: return const Color(0xFFFDD835);
      case LudoColor.blue:   return const Color(0xFF1E88E5);
    }
  }
}