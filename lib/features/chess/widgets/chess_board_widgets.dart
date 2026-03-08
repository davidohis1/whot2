import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../logic/chess_engine.dart';
import '../models/chess_models.dart';

// Board square colors — darker, more premium feel
const _sqLight = Color(0xFF9E7B4E); // warm tan
const _sqDark  = Color(0xFF3D2A1A); // deep espresso brown

class ChessBoardWidget extends StatelessWidget {
  final ChessGameModel game;
  final Position?      selected;
  final List<Position> validMoves;
  final bool           flipped;
  final void Function(Position) onTap;

  const ChessBoardWidget({
    super.key,
    required this.game,
    required this.selected,
    required this.validMoves,
    required this.flipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size      = MediaQuery.of(context).size;
    final boardSize = (size.width < size.height ? size.width : size.height) - 32;
    final sq        = boardSize / 8;

    final kingInCheck = ChessEngine.isInCheck(game, game.currentTurn);
    final kingPos     = _findKing(game.board, game.currentTurn);

    return Container(
      width:  boardSize + 20,
      height: boardSize + 20,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [Color(0xFF5C3D1E), Color(0xFF2A1A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.7),
              blurRadius: 28, spreadRadius: 6),
          BoxShadow(color: const Color(0xFF9E7B4E).withOpacity(0.15),
              blurRadius: 12, spreadRadius: -2),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Column(
          children: List.generate(8, (rawRow) {
            final row = flipped ? 7 - rawRow : rawRow;
            return Row(
              children: List.generate(8, (rawCol) {
                final col   = flipped ? 7 - rawCol : rawCol;
                final pos   = Position(row, col);
                final piece = game.board[row][col];
                final isLight = (row + col) % 2 == 0;
                final isSel   = selected == pos;
                final isValid = validMoves.contains(pos);
                final isCheck = kingInCheck && kingPos == pos;
                final lastMove = game.moveHistory.isNotEmpty
                    ? game.moveHistory.last : null;
                final isLast = lastMove != null &&
                    (lastMove.from == pos || lastMove.to == pos);

                return GestureDetector(
                  onTap: () => onTap(pos),
                  child: _Square(
                    size: sq, isLight: isLight,
                    isSel: isSel, isValid: isValid,
                    isCheck: isCheck, isLast: isLast,
                    piece: piece, col: rawCol, row: rawRow,
                  ),
                );
              }),
            );
          }),
        ),
      ),
    );
  }

  Position? _findKing(List<List<ChessPiece?>> board, PieceColor color) {
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = board[r][c];
        if (p != null && p.type == PieceType.king && p.color == color) {
          return Position(r, c);
        }
      }
    }
    return null;
  }
}

class _Square extends StatelessWidget {
  final double      size;
  final bool        isLight, isSel, isValid, isCheck, isLast;
  final ChessPiece? piece;
  final int         col, row;

  const _Square({
    required this.size,
    required this.isLight,
    required this.isSel,
    required this.isValid,
    required this.isCheck,
    required this.isLast,
    required this.piece,
    required this.col,
    required this.row,
  });

  Color get _base => isLight ? _sqLight : _sqDark;

  Color get _bg {
    if (isCheck) return const Color(0xFFCC2200).withOpacity(0.75);
    if (isSel)   return const Color(0xFF00E5CC).withOpacity(0.45);
    if (isLast)  return const Color(0xFFFFD700).withOpacity(0.25);
    return _base;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: Stack(children: [
        // Square background
        Container(color: _bg),

        // Subtle inner border on light squares for depth
        if (isLight && !isSel && !isCheck && !isLast)
          Positioned.fill(child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                  color: Colors.black.withOpacity(0.08), width: 0.5)),
          )),

        // Rank labels (left edge)
        if (col == 0)
          Positioned(top: 2, left: 3,
            child: Text('${8 - row}', style: TextStyle(
              fontSize: size * 0.18,
              color: isLight
                  ? _sqDark.withOpacity(0.7)
                  : _sqLight.withOpacity(0.7),
              fontWeight: FontWeight.w700)),
          ),

        // File labels (bottom edge)
        if (row == 7)
          Positioned(bottom: 2, right: 3,
            child: Text(String.fromCharCode('a'.codeUnitAt(0) + col),
              style: TextStyle(
                fontSize: size * 0.18,
                color: isLight
                    ? _sqDark.withOpacity(0.7)
                    : _sqLight.withOpacity(0.7),
                fontWeight: FontWeight.w700)),
          ),

        // Valid move indicator — dot for empty, ring for capture
        if (isValid && piece == null)
          Center(child: Container(
            width: size * 0.3, height: size * 0.3,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.28),
              shape: BoxShape.circle,
            ),
          )),
        if (isValid && piece != null)
          Center(child: Container(
            width: size * 0.92, height: size * 0.92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.black.withOpacity(0.35), width: size * 0.08),
            ),
          )),

        // Chess piece
        if (piece != null)
          Center(child: _PieceWidget(piece: piece!, size: size)),
      ]),
    );
  }
}

// ── Custom piece renderer ─────────────────────────────────────────────────────

class _PieceWidget extends StatelessWidget {
  final ChessPiece piece;
  final double     size;

  const _PieceWidget({required this.piece, required this.size});

  // Unicode pieces — white uses outlined style, black uses filled style
  String get _symbol {
    const w = {
      PieceType.king:   '♔',
      PieceType.queen:  '♕',
      PieceType.rook:   '♖',
      PieceType.bishop: '♗',
      PieceType.knight: '♘',
      PieceType.pawn:   '♙',
    };
    const b = {
      PieceType.king:   '♚',
      PieceType.queen:  '♛',
      PieceType.rook:   '♜',
      PieceType.bishop: '♝',
      PieceType.knight: '♞',
      PieceType.pawn:   '♟',
    };
    return piece.color == PieceColor.white
        ? w[piece.type]! : b[piece.type]!;
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = piece.color == PieceColor.white;
    final fs      = size * 0.70;

    return Stack(alignment: Alignment.center, children: [
      // Drop shadow layer — slightly offset dark copy
      Text(_symbol, style: TextStyle(
        fontSize: fs,
        foreground: Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.black.withOpacity(0.5),
      ), textAlign: TextAlign.center),

      // Outline stroke for contrast on any square
      Text(_symbol, style: TextStyle(
        fontSize: fs,
        foreground: Paint()
          ..style     = PaintingStyle.stroke
          ..strokeWidth = size * 0.045
          ..color     = isWhite
              ? const Color(0xFF1A0A00)   // dark brown outline on white
              : const Color(0xFFE8C97A),  // gold outline on black
      ), textAlign: TextAlign.center),

      // Fill layer
      Text(_symbol, style: TextStyle(
        fontSize: fs,
        foreground: Paint()
          ..style = PaintingStyle.fill
          ..color = isWhite
              ? const Color(0xFFF5F0E8)   // warm ivory white
              : const Color(0xFF1A0A00),  // near-black brown
      ), textAlign: TextAlign.center),
    ]);
  }
}