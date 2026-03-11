import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/auth_service.dart';
import '../logic/whot_engine.dart';
import '../logic/whot_service.dart';
import '../models/whot_models.dart';
import '../widgets/whot_card_widget.dart';

class WhotGameScreen extends ConsumerStatefulWidget {
  final String gameId;
  const WhotGameScreen({super.key, required this.gameId});

  @override
  ConsumerState<WhotGameScreen> createState() => _WhotGameScreenState();
}

class _WhotGameScreenState extends ConsumerState<WhotGameScreen> {
  Timer? _timer;
  bool   _resultShown = false;
  WhotCard? _selectedCard;

  Timer? _turnTimer;
  int    _localTurnSeconds = 10;
  String _lastTurnOwner    = '';

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _turnTimer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  String get _uid => ref.read(authStateProvider).valueOrNull?.uid ?? '';

  // ── Global game timer (runs on ALL devices, only writes if my turn) ────────
  void _startGlobalTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final g = ref.read(whotGameProvider(widget.gameId)).valueOrNull;
      if (g == null || g.status == WhotGameStatus.finished) {
        _timer?.cancel(); return;
      }
      // Only the current player writes the global countdown to Firestore
      final myIdx    = g.players.indexWhere((p) => p.uid == _uid);
      final isMyTurn = myIdx == g.currentPlayerIndex;
      if (!isMyTurn) return;

      final newTotal = g.timeLeftSeconds - 1;
      if (newTotal <= 0) {
        _timer?.cancel();
        await ref.read(whotServiceProvider).endByTimer(widget.gameId, g);
      } else {
        await ref.read(whotServiceProvider)
            .updateGlobalTimer(widget.gameId, newTotal);
      }
    });
  }

  // ── Per-turn timer (runs ONLY on current player's device) ──────────────────
  void _startTurnTimer(WhotGameModel game) {
    _turnTimer?.cancel();
    setState(() => _localTurnSeconds = 10);

    _turnTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      setState(() => _localTurnSeconds--);

      if (_localTurnSeconds <= 0) {
        _turnTimer?.cancel();
        final g = ref.read(whotGameProvider(widget.gameId)).valueOrNull;
        if (g == null) return;
        await ref.read(whotServiceProvider).skipTurn(widget.gameId, g);
      }
    });
  }

  // Called whenever the game state changes — detects whose turn it is
  void _handleTurnChange(WhotGameModel game) {
  final currentOwner = game.currentPlayer.uid;

  if (currentOwner != _lastTurnOwner) {
    _lastTurnOwner = currentOwner;
    _turnTimer?.cancel();

    if (currentOwner == _uid) {
      // Auto-draw if there's a pick penalty and we can't defend
      if (game.pending == WhotActionPending.pickTwo ||
          game.pending == WhotActionPending.pickThree) {
        final myIdx  = game.players.indexWhere((p) => p.uid == _uid);
        final hand   = game.players[myIdx].hand;
        final canDefend = game.pending == WhotActionPending.pickTwo
            ? hand.any((c) => c.number == 2)
            : hand.any((c) => c.number == 5);

        if (!canDefend) {
          // Auto-draw after a short delay so player can see what happened
          Future.delayed(const Duration(milliseconds: 800), () async {
            if (!mounted) return;
            final g = ref.read(whotGameProvider(widget.gameId)).valueOrNull;
            if (g == null) return;
            await ref.read(whotServiceProvider).drawCard(
              widget.gameId, g, count: g.pendingCount);
          });
          setState(() => _localTurnSeconds = 10);
          return; // don't start turn timer since it's auto-resolving
        }
      }
      _startTurnTimer(game);
    } else {
      setState(() => _localTurnSeconds = 10);
    }
  }
}

  void _onCardTap(WhotCard card, WhotGameModel game) {
    final myIdx = game.players.indexWhere((p) => p.uid == _uid);
    if (myIdx != game.currentPlayerIndex) return;

    final playable = WhotEngine.playableCards(game, game.players[myIdx].hand);
    if (!playable.contains(card)) return;

    setState(() => _selectedCard = card);

    if (card.isWhot) {
      _showCallShapeDialog(card, game);
    } else {
      _playCard(card, game);
    }
  }

  void _playCard(WhotCard card, WhotGameModel game, {WhotShape? called}) async {
    final myIdx       = game.players.indexWhere((p) => p.uid == _uid);
    final hand        = game.players[myIdx].hand;
    final willBeOne   = hand.length == 2; // after playing this card, 1 left

    // Show "Last Card!" dialog if going to 1 card
    if (willBeOne) {
      final declared = await _showLastCardDialog();
      await ref.read(whotServiceProvider).playCard(
        widget.gameId, game, card,
        calledShape: called,
        declaredLastCard: declared,
      );
    } else {
      await ref.read(whotServiceProvider).playCard(
        widget.gameId, game, card,
        calledShape: called,
        declaredLastCard: false,
      );
    }
    setState(() => _selectedCard = null);
  }

  Future<bool> _showLastCardDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg2,
        title: const Text('⚠ Last Card!', style: TextStyle(color: AppColors.warning)),
        content: const Text('Declare "Last Card!" to warn other players.',
            style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('LAST CARD! 🃏', style: TextStyle(color: Colors.black,
                fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showCallShapeDialog(WhotCard card, WhotGameModel game) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg2,
        title: const Text('Call a Shape', style: TextStyle(color: AppColors.textPrimary)),
        content: Wrap(
          spacing: 12, runSpacing: 12,
          children: [
            WhotShape.circle, WhotShape.triangle, WhotShape.cross,
            WhotShape.square, WhotShape.star,
          ].map((shape) => GestureDetector(
            onTap: () {
              Navigator.pop(context);
              _playCard(card, game, called: shape);
            },
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: _shapeColor(shape).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _shapeColor(shape), width: 2),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_shapeEmoji(shape), style: const TextStyle(fontSize: 24)),
                Text(_shapeName(shape), style: const TextStyle(
                    fontSize: 9, color: AppColors.textPrimary)),
              ]),
            ),
          )).toList(),
        ),
      ),
    );
  }

  Future<void> _drawFromMarket(WhotGameModel game) async {
    final myIdx = game.players.indexWhere((p) => p.uid == _uid);
    if (myIdx != game.currentPlayerIndex) return;
    final count = game.pending != WhotActionPending.none
        ? game.pendingCount : 1;
    await ref.read(whotServiceProvider).drawCard(widget.gameId, game, count: count);
  }

  void _handleGameEnd(WhotGameModel game) {
    if (_resultShown || game.status != WhotGameStatus.finished) return;
    _resultShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showResultDialog(game));
  }

  void _showResultDialog(WhotGameModel game) {
    final myRank   = game.rankings.indexOf(_uid) + 1;
    final is2p = game.playerCount == 2;
    final prizes = is2p
        ? {1: '+700 🪙', 2: '-400 🪙'}
        : {1: '+1000 🪙', 2: '+300 🪙', 3: '-400 🪙', 4: '-400 🪙'};
    final colors = {
      1: AppColors.gold,
      2: is2p ? AppColors.danger : AppColors.teal,
      3: AppColors.danger,
      4: AppColors.danger,
    };
    final labels = {
      1: '🥇 1st Place!',
      2: is2p ? '2nd Place' : '🥈 2nd Place',
      3: '🥉 3rd Place',
      4: '4th Place',
    };
  
  

    // Build card count map for display
    final cardCounts = {
      for (final p in game.players) p.uid: p.hand.length,
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg2,
        title: Text(labels[myRank] ?? '',
            style: TextStyle(color: colors[myRank], fontSize: 24)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(prizes[myRank] ?? '', style: TextStyle(
              color: colors[myRank], fontSize: 22,
              fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          // Show reason
          Text(
            myRank == 1
                ? 'You played all your cards first!'
                : 'Ranked by cards remaining',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11),
          ),
          const Divider(color: AppColors.divider, height: 20),
          // Rankings table
          ...List.generate(game.rankings.length, (i) {
            final uid   = game.rankings[i];
            final p     = game.players.firstWhere(
              (pl) => pl.uid == uid,
              orElse: () => WhotPlayer(
                  uid: uid, name: uid, hand: [], position: i),
            );
            final isMe  = uid == _uid;
            final cards = i == 0 ? 0 : (cardCounts[uid] ?? 0);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isMe
                    ? colors[i + 1]!.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isMe
                    ? Border.all(color: colors[i + 1]!.withOpacity(0.4))
                    : null,
              ),
              child: Row(children: [
                Text(
                  i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '4️⃣',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.name + (isMe ? ' (You)' : ''),
                    style: TextStyle(
                      color: isMe
                          ? colors[i + 1]
                          : AppColors.textPrimary,
                      fontWeight: isMe
                          ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ),
                // Card count (0 for winner)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.bg3,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    i == 0 ? '✓ 0' : '🃏 $cards',
                    style: TextStyle(
                      color: i == 0
                          ? AppColors.success
                          : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(prizes[i + 1] ?? '',
                    style: TextStyle(
                      color: colors[i + 1],
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    )),
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
              context.go('/whot/lobby');
            },
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameAsync = ref.watch(whotGameProvider(widget.gameId));
    return gameAsync.when(
      loading: () => const Scaffold(
          backgroundColor: AppColors.bg0,
          body: Center(child: CircularProgressIndicator(color: AppColors.gold))),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (game) {
        if (game == null) return const Scaffold(
            body: Center(child: Text('Game not found')));

        if (game.status == WhotGameStatus.active) {
          if (_timer == null || !_timer!.isActive) _startGlobalTimer();
          _handleTurnChange(game);
        }
        _handleGameEnd(game);

        final myIdx   = game.players.indexWhere((p) => p.uid == _uid);
        final me      = myIdx >= 0 ? game.players[myIdx] : null;
        final isMyTurn = myIdx == game.currentPlayerIndex;

        return Scaffold(
          backgroundColor: const Color(0xFF1A2A1A),
          body: SafeArea(
            child: Stack(children: [
              // Green felt background
              Container(decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0xFF1E3A1E), Color(0xFF0D1A0D)],
                  radius: 1.2,
                ),
              )),

              Column(children: [
                _topBar(game),
                Expanded(
                  child: Row(children: [
                    // Left player
                    // Left player
                    if (game.playerCount == 4) _sidePlayer(game, myIdx, 1),
                    // Centre table
                    Expanded(child: _centreTable(game, isMyTurn)),
                    // Right player
                    if (game.playerCount == 4) _sidePlayer(game, myIdx, 2),
                  ]),
                ),
                // Bottom — my hand
                if (me != null) _myHand(game, me, isMyTurn),
              ]),

              // Pending action banner
              if (isMyTurn && game.pending != WhotActionPending.none)
                Positioned(top: 48, left: 0, right: 0, child: _pendingBanner(game)),
            ]),
          ),
        );
      },
    );
  }

  Widget _topBar(WhotGameModel game) {
    final mins     = game.timeLeftSeconds ~/ 60;
    final secs     = game.timeLeftSeconds % 60;
    final time     = '${mins.toString().padLeft(2,'0')}:${secs.toString().padLeft(2,'0')}';
    final lowGame  = game.timeLeftSeconds < 60;
    final myIdx    = _myIdx(game);
    final isMyTurn = myIdx == game.currentPlayerIndex;
    final lowTurn  = _localTurnSeconds <= 3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.black.withOpacity(0.4),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.home, color: Colors.white54, size: 20),
          onPressed: () => context.go('/home'),
        ),
        const Text('WHOT', style: TextStyle(
            color: AppColors.gold, fontWeight: FontWeight.w700,
            fontSize: 16, letterSpacing: 2)),
        const Spacer(),
        if (game.playerCount == 4)
          _opponentChip(game, _opponentIdx(game, myIdx < 0 ? 0 : myIdx, 2))
        else
          _opponentChip(game, _opponentIdx(game, myIdx < 0 ? 0 : myIdx, 1)),
        const SizedBox(width: 8),

        // Turn countdown — only visible on MY screen when it's MY turn
        if (isMyTurn)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: lowTurn
                  ? AppColors.danger.withOpacity(0.35)
                  : AppColors.teal.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: lowTurn ? AppColors.danger : AppColors.teal),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.timer, size: 12,
                  color: lowTurn ? AppColors.danger : AppColors.teal),
              const SizedBox(width: 3),
              Text('${_localTurnSeconds}s', style: TextStyle(
                  color: lowTurn ? AppColors.danger : AppColors.teal,
                  fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),

        // Global game timer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: lowGame
                ? AppColors.danger.withOpacity(0.3) : Colors.black38,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: lowGame ? AppColors.danger : Colors.white24),
          ),
          child: Text(time, style: TextStyle(
              color: lowGame ? AppColors.danger : Colors.white,
              fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ]),
    );
  }

  int _myIdx(WhotGameModel game) =>
      game.players.indexWhere((p) => p.uid == _uid);

  int _opponentIdx(WhotGameModel game, int myIdx, int offset) =>
      (myIdx + offset) % game.players.length;

  Widget _opponentChip(WhotGameModel game, int idx) {
    if (idx < 0 || idx >= game.players.length) return const SizedBox.shrink();
    final p      = game.players[idx];
    final active = game.currentPlayerIndex == idx;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppColors.gold.withOpacity(0.2) : Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? AppColors.gold : Colors.white24),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 11)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black38, borderRadius: BorderRadius.circular(4)),
          child: Text('${p.hand.length}', style: const TextStyle(
              color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
        if (p.declaredLastCard) ...[
          const SizedBox(width: 4),
          const Text('⚠', style: TextStyle(fontSize: 10)),
        ],
      ]),
    );
  }

  Widget _sidePlayer(WhotGameModel game, int myIdx, int offset) {
    if (game.playerCount == 2) return const SizedBox(width: 0);
    final idx = _opponentIdx(game, myIdx < 0 ? 0 : myIdx, offset);
    if (idx < 0 || idx >= game.players.length) return const SizedBox(width: 48);
    final p      = game.players[idx];
    final active = game.currentPlayerIndex == idx;

    return Container(
      width: 52,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.gold.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? AppColors.gold : Colors.white12, width: active ? 2 : 1),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(p.name.split(' ').first, style: const TextStyle(
            color: Colors.white70, fontSize: 9),
            textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        // Card stack representation
        Stack(alignment: Alignment.center,
          children: List.generate(min(p.hand.length, 5), (i) => Transform.translate(
            offset: Offset(0, i * -3.0),
            child: Container(
              width: 28, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A6A),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white30),
              ),
            ),
          )),
        ),
        const SizedBox(height: 6),
        Text('${p.hand.length}', style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        if (p.declaredLastCard)
          const Text('⚠ Last!', style: TextStyle(color: AppColors.warning, fontSize: 8)),
      ]),
    );
  }

  Widget _centreTable(WhotGameModel game, bool isMyTurn) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      // Top opponent
      // Top opponent
      if (game.playerCount == 4)
        _opponentChip(game, _opponentIdx(game, _myIdx(game), 2))
      else
        _opponentChip(game, _opponentIdx(game, _myIdx(game), 1)),
      const Spacer(),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        // Market
        GestureDetector(
          onTap: isMyTurn ? () => _drawFromMarket(game) : null,
          child: Column(children: [
            _cardBack(isMyTurn),
            const SizedBox(height: 4),
            Text('Market (${game.market.length})',
                style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ]),
        ),
        const SizedBox(width: 24),
        // Top of pile
        Column(children: [
          WhotCardWidget(card: game.topCard, size: _cardSize),
          const SizedBox(height: 4),
          if (game.calledShape != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _shapeColor(game.calledShape!).withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _shapeColor(game.calledShape!)),
              ),
              child: Text('Called: ${_shapeName(game.calledShape!)}',
                  style: TextStyle(color: _shapeColor(game.calledShape!), fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
        ]),
      ]),
      const Spacer(),
      // Turn indicator
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isMyTurn ? AppColors.teal.withOpacity(0.2) : Colors.black26,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isMyTurn ? '⚡ YOUR TURN' : '${game.currentPlayer.name}\'s turn',
          style: TextStyle(
            color: isMyTurn ? AppColors.teal : Colors.white54,
            fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
      ),
    ]);
  }

  Widget _cardBack(bool tappable) => Container(
    width: _cardSize, height: _cardSize * 1.4,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: tappable
            ? [const Color(0xFF1A3A6A), const Color(0xFF0D2040)]
            : [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: tappable ? AppColors.teal.withOpacity(0.5) : Colors.white12, width: 2),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 6)],
    ),
    child: Center(child: Text('🂠', style: TextStyle(
        fontSize: _cardSize * 0.5,
        color: tappable ? AppColors.teal : Colors.white24))),
  );

  Widget _myHand(WhotGameModel game, WhotPlayer me, bool isMyTurn) {
    final playable = isMyTurn
        ? WhotEngine.playableCards(game, me.hand).toSet() : <WhotCard>{};

    return Container(
      color: Colors.black.withOpacity(0.35),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(me.name, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Text('${me.hand.length} cards', style: const TextStyle(
              color: Colors.white54, fontSize: 10)),
        ]),
        const SizedBox(height: 6),
        SizedBox(
          height: _cardSize * 1.4 + 8,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: me.hand.length,
            itemBuilder: (_, i) {
              final card  = me.hand[i];
              final canPlay = playable.contains(card);
              return GestureDetector(
                onTap: canPlay ? () => _onCardTap(card, game) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  transform: Matrix4.translationValues(0,
                      _selectedCard == card ? -12 : (canPlay ? -6 : 0), 0),
                  child: Opacity(
                    opacity: !isMyTurn || canPlay ? 1.0 : 0.45,
                    child: WhotCardWidget(card: card, size: _cardSize),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _pendingBanner(WhotGameModel game) {
    String msg = '';
    Color  col = AppColors.danger;
    if (game.pending == WhotActionPending.pickTwo) {
      msg = '⚠ You have a 2! Play it to defend or cards will be drawn.';
    } else if (game.pending == WhotActionPending.pickThree) {
      msg = '⚠ You have a 5! Play it to defend or cards will be drawn.';
    }else if (game.pending == WhotActionPending.suspension) {
      msg = '⛔ Suspended — you lose your turn!';
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: col.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(msg, style: const TextStyle(color: Colors.white,
          fontWeight: FontWeight.w700, fontSize: 12),
          textAlign: TextAlign.center),
    ).animate().shake();
  }

  double get _cardSize => 56.0;

  Color _shapeColor(WhotShape s) {
    const map = {
      WhotShape.circle:   AppColors.circle,
      WhotShape.triangle: AppColors.triangle,
      WhotShape.cross:    AppColors.cross,
      WhotShape.square:   AppColors.square,
      WhotShape.star:     AppColors.star,
      WhotShape.whot:     AppColors.whotCard,
    };
    return map[s] ?? Colors.white;
  }

  String _shapeEmoji(WhotShape s) => WhotCard(shape: s, number: 1).shapeEmoji;
  String _shapeName(WhotShape s)  => WhotCard(shape: s, number: 1).shapeName;

  int min(int a, int b) => a < b ? a : b;
}