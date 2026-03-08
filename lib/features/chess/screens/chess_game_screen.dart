import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/auth_service.dart';
import '../logic/chess_engine.dart';
import '../logic/chess_service.dart';
import '../models/chess_models.dart';
import '../widgets/chess_board_widgets.dart';
import '../widgets/promotion_dialog.dart';

class ChessGameScreen extends ConsumerStatefulWidget {
  final String gameId;
  const ChessGameScreen({super.key, required this.gameId});

  @override
  ConsumerState<ChessGameScreen> createState() => _ChessGameScreenState();
}

class _ChessGameScreenState extends ConsumerState<ChessGameScreen> {
  Position? _selected;
  List<Position> _validMoves = [];
  Timer? _timer;
  bool _awaitingPromotion = false;
  ChessMove? _pendingPromoMove;
  bool _resultShown = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _uid => ref.read(authStateProvider).valueOrNull?.uid ?? '';

  void _startTimer(ChessGameModel game) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final g = ref.read(chessGameProvider(widget.gameId)).valueOrNull;
      if (g == null) return;
      if (g.status != GameStatus.active && g.status != GameStatus.check &&
          g.status != GameStatus.armageddon) {
        _timer?.cancel(); return;
      }

      final isWhiteTurn = g.currentTurn == PieceColor.white;
      final newW = isWhiteTurn ? g.whiteTimeSeconds - 1 : g.whiteTimeSeconds;
      final newB = isWhiteTurn ? g.blackTimeSeconds     : g.blackTimeSeconds - 1;

      if (newW <= 0 || newB <= 0) {
        _timer?.cancel();
        final loser = newW <= 0 ? PieceColor.white : PieceColor.black;

        // Armageddon draw odds — if black runs out, white wins normally
        // If white runs out, black wins normally
        await ref.read(chessServiceProvider).flagOnTimeout(widget.gameId, g, loser);
        return;
      }

      await ref.read(chessServiceProvider).updateTimer(
        widget.gameId,
        g.currentTurn,
        isWhiteTurn ? newW : newB,
      );
    });
  }

  void _onSquareTap(Position pos, ChessGameModel game) {
    if (_awaitingPromotion) return;

    final myColor = game.whitePlayerId == _uid ? PieceColor.white : PieceColor.black;
    if (game.currentTurn != myColor) return;
    if (game.status == GameStatus.checkmate || game.status == GameStatus.draw ||
        game.status == GameStatus.stalemate) return;

    final piece = game.board[pos.row][pos.col];

    if (_selected == null) {
      if (piece != null && piece.color == myColor) {
        final moves = ChessEngine.legalMovesFor(game, pos);
        setState(() { _selected = pos; _validMoves = moves; });
      }
      return;
    }

    if (_validMoves.contains(pos)) {
      final move = ChessMove(
        from:        _selected!,
        to:          pos,
        isEnPassant: game.enPassantTarget == pos,
        isCastle:    piece?.type == PieceType.king
            ? (pos.col - _selected!.col).abs() == 2 : false,
      );

      // Check promotion
      final movingPiece = game.board[_selected!.row][_selected!.col]!;
      if (movingPiece.type == PieceType.pawn && (pos.row == 0 || pos.row == 7)) {
        setState(() {
          _awaitingPromotion = true;
          _pendingPromoMove  = move;
          _selected          = null;
          _validMoves        = [];
        });
        return;
      }

      _submitMove(game, move);
    } else if (piece != null && piece.color == myColor) {
      final moves = ChessEngine.legalMovesFor(game, pos);
      setState(() { _selected = pos; _validMoves = moves; });
    } else {
      setState(() { _selected = null; _validMoves = []; });
    }
  }

  Future<void> _submitMove(ChessGameModel game, ChessMove move, {PieceType? promo}) async {
    setState(() { _selected = null; _validMoves = []; _awaitingPromotion = false; });
    await ref.read(chessServiceProvider).makeMove(widget.gameId, game, move, promotion: promo);
  }

  void _handleGameEnd(ChessGameModel game) {
    if (_resultShown) return;
    if (game.status != GameStatus.checkmate && game.status != GameStatus.draw &&
        game.status != GameStatus.stalemate) return;

    // Stalemate in normal → trigger armageddon
    if ((game.status == GameStatus.stalemate || game.status == GameStatus.draw) &&
        !game.isArmageddon) {
      _resultShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showArmageddonDialog(game));
      return;
    }

    _resultShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showResultDialog(game));
  }

  void _showArmageddonDialog(ChessGameModel game) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg2,
        title: const Text('⚔ Draw!', style: TextStyle(color: Colors.amber, fontSize: 22)),
        content: const Column(mainAxisSize: MainAxisSize.min, children: [
          Text('The game ended in a draw.\nArmageddon time!',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              textAlign: TextAlign.center),
          SizedBox(height: 12),
          Text('⚡ White: 5 min   Black: 4 min\nBlack wins on draw.',
              style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
        ]),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(chessServiceProvider).startArmageddon(widget.gameId, game);
              setState(() => _resultShown = false);
            },
            child: const Text('Start Armageddon'),
          ),
        ],
      ),
    );
  }

  void _showResultDialog(ChessGameModel game) {
    final isWinner = game.winnerId == _uid;
    final isDraw   = game.status == GameStatus.stalemate &&
        (game.isArmageddon ? game.winnerId != null : false);
    final title    = game.status == GameStatus.checkmate
        ? (isWinner ? '🏆 You Win!' : '💀 You Lose')
        : '🤝 Draw';
    final coinDelta = isWinner ? '+700' : '-400';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg2,
        title: Text(title, style: TextStyle(
          color: isWinner ? AppColors.gold : AppColors.danger, fontSize: 26)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(isWinner ? 'You earned $coinDelta 🪙' : 'You lost 400 🪙',
              style: TextStyle(
                color: isWinner ? AppColors.gold : AppColors.danger,
                fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(_resultSubtitle(game), style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 13)),
        ]),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); context.go('/home'); },
            child: const Text('Home', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); context.go('/chess/lobby'); },
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  String _resultSubtitle(ChessGameModel game) {
    if (game.status == GameStatus.checkmate)  return 'Checkmate!';
    if (game.status == GameStatus.stalemate)  return 'Stalemate';
    if (game.isArmageddon && game.winnerId != null) return 'Armageddon — draw odds applied';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final gameAsync = ref.watch(chessGameProvider(widget.gameId));

    return gameAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator(color: AppColors.teal))),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (game) {
        if (game == null) return const Scaffold(
            body: Center(child: Text('Game not found')));

        // Start timer once
        if (game.status == GameStatus.active || game.status == GameStatus.check ||
            game.status == GameStatus.armageddon) {
          if (_timer == null || !_timer!.isActive) _startTimer(game);
        }

        // Handle end
        _handleGameEnd(game);

        final myColor   = game.whitePlayerId == _uid ? PieceColor.white : PieceColor.black;
        final isMyTurn  = game.currentTurn == myColor;
        final inCheck   = ChessEngine.isInCheck(game, game.currentTurn);
        final flipped   = myColor == PieceColor.black;

        return Scaffold(
          backgroundColor: AppColors.bg0,
          body: SafeArea(
            child: Column(children: [
              _topBar(game, myColor, flipped),
              const SizedBox(height: 8),
              if (inCheck && game.status != GameStatus.checkmate)
                _checkBanner().animate().shake(),
              Expanded(
                child: Center(
                  child: ChessBoardWidget(
                    game:        game,
                    selected:    _selected,
                    validMoves:  _validMoves,
                    flipped:     flipped,
                    onTap:       (pos) => _onSquareTap(pos, game),
                  ),
                ),
              ),
              if (_awaitingPromotion)
                PromotionDialog(
                  color:    myColor,
                  onSelect: (type) => _submitMove(game, _pendingPromoMove!, promo: type),
                ),
              const SizedBox(height: 8),
              _bottomBar(game, myColor, isMyTurn),
            ]),
          ),
        );
      },
    );
  }

  Widget _checkBanner() => Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.danger.withOpacity(0.2),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.danger.withOpacity(0.5)),
    ),
    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.warning_rounded, color: AppColors.danger, size: 18),
      SizedBox(width: 8),
      Text('⚠  KING IN CHECK!', style: TextStyle(
          color: AppColors.danger, fontWeight: FontWeight.w700, letterSpacing: 1)),
    ]),
  );

  Widget _topBar(ChessGameModel game, PieceColor myColor, bool flipped) {
    final oppColor  = flipped ? PieceColor.white : PieceColor.black;
    final oppName   = oppColor == PieceColor.white ? game.whitePlayerName : game.blackPlayerName;
    final oppTime   = oppColor == PieceColor.white ? game.whiteTimeSeconds : game.blackTimeSeconds;
    final oppTurn   = game.currentTurn == oppColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.home, color: AppColors.textSecondary),
          onPressed: () => context.go('/home'),
        ),
        const Spacer(),
        _playerChip(oppName, oppTime, oppTurn, oppColor),
      ]),
    );
  }

  Widget _bottomBar(ChessGameModel game, PieceColor myColor, bool isMyTurn) {
    final myName  = myColor == PieceColor.white ? game.whitePlayerName : game.blackPlayerName;
    final myTime  = myColor == PieceColor.white ? game.whiteTimeSeconds : game.blackTimeSeconds;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        _playerChip(myName, myTime, isMyTurn, myColor),
        const Spacer(),
        if (isMyTurn)
          const Text('Your Turn', style: TextStyle(
              color: AppColors.teal, fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );
  }

  Widget _playerChip(String name, int secs, bool active, PieceColor color) {
    final mins = secs ~/ 60;
    final s    = secs % 60;
    final time = '${mins.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
    final isLow = secs < 30;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.teal.withOpacity(0.15) : AppColors.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? AppColors.teal : AppColors.cardBorder,
          width: active ? 2 : 1,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: color == PieceColor.white ? Colors.white : Colors.black,
          child: Text(color == PieceColor.white ? '♔' : '♚',
              style: TextStyle(
                  fontSize: 14,
                  color: color == PieceColor.white ? Colors.black : Colors.white)),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(name, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary,
              fontWeight: FontWeight.w600)),
          Text(time, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: isLow ? AppColors.danger : AppColors.textPrimary)),
        ]),
      ]),
    );
  }
}