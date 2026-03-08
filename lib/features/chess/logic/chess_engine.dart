// ══════════════════════════════════════════════════════════════════════════════
// Chess Engine — Pure logic, zero dependencies
// ══════════════════════════════════════════════════════════════════════════════
import '../models/chess_models.dart';

class ChessEngine {
  // ── Initial board ─────────────────────────────────────────────────────────

  static List<List<ChessPiece?>> createInitialBoard() {
    final board = List.generate(8, (_) => List<ChessPiece?>.filled(8, null));

    void place(int r, int c, PieceType t, PieceColor color) =>
        board[r][c] = ChessPiece(type: t, color: color);

    const order = [
      PieceType.rook, PieceType.knight, PieceType.bishop, PieceType.queen,
      PieceType.king, PieceType.bishop, PieceType.knight, PieceType.rook,
    ];

    for (int c = 0; c < 8; c++) {
      place(0, c, order[c], PieceColor.black);
      place(1, c, PieceType.pawn, PieceColor.black);
      place(6, c, PieceType.pawn, PieceColor.white);
      place(7, c, order[c], PieceColor.white);
    }
    return board;
  }

  // ── Board copy ────────────────────────────────────────────────────────────

  static List<List<ChessPiece?>> copyBoard(List<List<ChessPiece?>> b) =>
      b.map((r) => List<ChessPiece?>.from(r)).toList();

  // ── Legal moves ───────────────────────────────────────────────────────────

  /// Returns all legal destination squares for the piece at [from].
  static List<Position> legalMovesFor(ChessGameModel game, Position from) {
    final piece = game.board[from.row][from.col];
    if (piece == null) return [];

    final pseudo = _pseudoLegal(game, from, piece);
    return pseudo.where((to) {
      final simulated = _applyMoveSimulated(game, ChessMove(from: from, to: to));
      return !isInCheck(simulated, piece.color);
    }).toList();
  }

  /// All pseudo-legal moves (may leave own king in check).
  static List<Position> _pseudoLegal(
      ChessGameModel game, Position from, ChessPiece piece) {
    switch (piece.type) {
      case PieceType.pawn:   return _pawnMoves(game, from, piece.color);
      case PieceType.knight: return _knightMoves(game, from, piece.color);
      case PieceType.bishop: return _slidingMoves(game, from, piece.color, _bishopDirs);
      case PieceType.rook:   return _slidingMoves(game, from, piece.color, _rookDirs);
      case PieceType.queen:  return _slidingMoves(game, from, piece.color, [..._bishopDirs, ..._rookDirs]);
      case PieceType.king:   return _kingMoves(game, from, piece.color);
    }
  }

  // ── Pawn ─────────────────────────────────────────────────────────────────

  static List<Position> _pawnMoves(ChessGameModel g, Position from, PieceColor color) {
    final moves = <Position>[];
    final dir   = color == PieceColor.white ? -1 : 1;
    final start = color == PieceColor.white ?  6  : 1;

    // Forward
    final one = Position(from.row + dir, from.col);
    if (one.isValid && g.board[one.row][one.col] == null) {
      moves.add(one);
      // Double advance from start rank
      if (from.row == start) {
        final two = Position(from.row + dir * 2, from.col);
        if (g.board[two.row][two.col] == null) moves.add(two);
      }
    }

    // Captures
    for (final dc in [-1, 1]) {
      final cap = Position(from.row + dir, from.col + dc);
      if (!cap.isValid) continue;
      final target = g.board[cap.row][cap.col];
      if (target != null && target.color != color) moves.add(cap);
      // En passant
      if (g.enPassantTarget != null && cap == g.enPassantTarget) moves.add(cap);
    }
    return moves;
  }

  // ── Knight ───────────────────────────────────────────────────────────────

  static const _knightOffsets = [
    [-2,-1],[-2,1],[-1,-2],[-1,2],[1,-2],[1,2],[2,-1],[2,1],
  ];

  static List<Position> _knightMoves(ChessGameModel g, Position from, PieceColor color) {
    final moves = <Position>[];
    for (final off in _knightOffsets) {
      final p = Position(from.row + off[0], from.col + off[1]);
      if (!p.isValid) continue;
      final t = g.board[p.row][p.col];
      if (t == null || t.color != color) moves.add(p);
    }
    return moves;
  }

  // ── Sliding pieces ────────────────────────────────────────────────────────

  static const _bishopDirs = [[-1,-1],[-1,1],[1,-1],[1,1]];
  static const _rookDirs   = [[-1, 0],[1, 0],[0,-1],[0, 1]];

  static List<Position> _slidingMoves(
      ChessGameModel g, Position from, PieceColor color, List<List<int>> dirs) {
    final moves = <Position>[];
    for (final d in dirs) {
      var r = from.row + d[0];
      var c = from.col + d[1];
      while (r >= 0 && r < 8 && c >= 0 && c < 8) {
        final t = g.board[r][c];
        if (t == null) {
          moves.add(Position(r, c));
        } else {
          if (t.color != color) moves.add(Position(r, c));
          break;
        }
        r += d[0]; c += d[1];
      }
    }
    return moves;
  }

  // ── King ─────────────────────────────────────────────────────────────────

  static List<Position> _kingMoves(ChessGameModel g, Position from, PieceColor color) {
    final moves = <Position>[];
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final p = Position(from.row + dr, from.col + dc);
        if (!p.isValid) continue;
        final t = g.board[p.row][p.col];
        if (t == null || t.color != color) moves.add(p);
      }
    }

    // Castling
    _addCastlingMoves(g, from, color, moves);
    return moves;
  }

  static void _addCastlingMoves(
      ChessGameModel g, Position kingPos, PieceColor color, List<Position> moves) {
    if (isInCheck(g, color)) return;

    final row = color == PieceColor.white ? 7 : 0;
    if (kingPos.row != row || kingPos.col != 4) return;

    // Kingside
    final ksCan = color == PieceColor.white
        ? g.whiteCanCastleKingside
        : g.blackCanCastleKingside;
    if (ksCan) {
      if (g.board[row][5] == null &&
          g.board[row][6] == null &&
          !_squareAttacked(g, Position(row, 5), color) &&
          !_squareAttacked(g, Position(row, 6), color)) {
        moves.add(Position(row, 6));
      }
    }

    // Queenside
    final qsCan = color == PieceColor.white
        ? g.whiteCanCastleQueenside
        : g.blackCanCastleQueenside;
    if (qsCan) {
      if (g.board[row][3] == null &&
          g.board[row][2] == null &&
          g.board[row][1] == null &&
          !_squareAttacked(g, Position(row, 3), color) &&
          !_squareAttacked(g, Position(row, 2), color)) {
        moves.add(Position(row, 2));
      }
    }
  }

  // ── Check / attack detection ──────────────────────────────────────────────

  static bool isInCheck(ChessGameModel g, PieceColor color) {
    final kingPos = _findKing(g.board, color);
    if (kingPos == null) return false;
    return _squareAttacked(g, kingPos, color);
  }

  static bool _squareAttacked(ChessGameModel g, Position sq, PieceColor byOpponent) {
    final opp = byOpponent == PieceColor.white ? PieceColor.black : PieceColor.white;
    // Check all opponent pieces
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = g.board[r][c];
        if (p == null || p.color != opp) continue;
        final attacks = _attackSquares(g, Position(r, c), p);
        if (attacks.contains(sq)) return true;
      }
    }
    return false;
  }

  static List<Position> _attackSquares(ChessGameModel g, Position from, ChessPiece piece) {
    // Same as pseudo-legal but for pawns we only include diagonal attacks
    if (piece.type == PieceType.pawn) {
      final dir = piece.color == PieceColor.white ? -1 : 1;
      return [
        Position(from.row + dir, from.col - 1),
        Position(from.row + dir, from.col + 1),
      ].where((p) => p.isValid).toList();
    }
    return _pseudoLegalNoEnPassant(g, from, piece);
  }

  static List<Position> _pseudoLegalNoEnPassant(
      ChessGameModel g, Position from, ChessPiece piece) {
    switch (piece.type) {
      case PieceType.knight: return _knightMoves(g, from, piece.color);
      case PieceType.bishop: return _slidingMoves(g, from, piece.color, _bishopDirs);
      case PieceType.rook:   return _slidingMoves(g, from, piece.color, _rookDirs);
      case PieceType.queen:  return _slidingMoves(g, from, piece.color, [..._bishopDirs, ..._rookDirs]);
      case PieceType.king:   return _kingMovesBasic(g, from, piece.color);
      default:               return [];
    }
  }

  static List<Position> _kingMovesBasic(ChessGameModel g, Position from, PieceColor color) {
    final moves = <Position>[];
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final p = Position(from.row + dr, from.col + dc);
        if (!p.isValid) continue;
        final t = g.board[p.row][p.col];
        if (t == null || t.color != color) moves.add(p);
      }
    }
    return moves;
  }

  static Position? _findKing(List<List<ChessPiece?>> board, PieceColor color) {
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

  // ── Apply move ────────────────────────────────────────────────────────────

  /// Simulates a move and returns the resulting game state (used for check detection).
  static ChessGameModel _applyMoveSimulated(ChessGameModel g, ChessMove move) {
    final board = copyBoard(g.board);
    _execMove(board, move, g.enPassantTarget);
    return g.copyWith(board: board, clearEnPassant: true);
  }

  /// Applies a full legal move, updating all state (turn, castling rights, en passant, status).
  static ChessGameModel applyMove(ChessGameModel g, ChessMove move, {PieceType? promotion}) {
    final board = copyBoard(g.board);
    Position? newEnPassant;
    final piece = board[move.from.row][move.from.col]!;

    // En passant target tracking
    if (piece.type == PieceType.pawn) {
      final rowDiff = (move.to.row - move.from.row).abs();
      if (rowDiff == 2) {
        newEnPassant = Position(
          (move.from.row + move.to.row) ~/ 2,
          move.from.col,
        );
      }
    }

    // Update castling rights
    bool wCK = g.whiteCanCastleKingside;
    bool wCQ = g.whiteCanCastleQueenside;
    bool bCK = g.blackCanCastleKingside;
    bool bCQ = g.blackCanCastleQueenside;

    if (piece.type == PieceType.king) {
      if (piece.color == PieceColor.white) { wCK = false; wCQ = false; }
      else { bCK = false; bCQ = false; }
    }
    if (piece.type == PieceType.rook) {
      if (move.from == const Position(7, 7)) wCK = false;
      if (move.from == const Position(7, 0)) wCQ = false;
      if (move.from == const Position(0, 7)) bCK = false;
      if (move.from == const Position(0, 0)) bCQ = false;
    }

    _execMove(board, move, g.enPassantTarget, promotion: promotion);

    final next = g.currentTurn == PieceColor.white ? PieceColor.black : PieceColor.white;

    final newHistory = [...g.moveHistory, move];

    var newState = g.copyWith(
      board:                   board,
      currentTurn:             next,
      moveHistory:             newHistory,
      enPassantTarget:         newEnPassant,
      clearEnPassant:          newEnPassant == null,
      whiteCanCastleKingside:  wCK,
      whiteCanCastleQueenside: wCQ,
      blackCanCastleKingside:  bCK,
      blackCanCastleQueenside: bCQ,
    );

    // Determine game status
    newState = _computeStatus(newState);
    return newState;
  }

  static void _execMove(
    List<List<ChessPiece?>> board,
    ChessMove move,
    Position? enPassantTarget, {
    PieceType? promotion,
  }) {
    var piece = board[move.from.row][move.from.col]!;

    // Castling
    if (piece.type == PieceType.king) {
      final colDiff = move.to.col - move.from.col;
      if (colDiff == 2) {
        // Kingside — move rook
        board[move.from.row][5] = board[move.from.row][7]!.copyWith(hasMoved: true);
        board[move.from.row][7] = null;
      } else if (colDiff == -2) {
        // Queenside — move rook
        board[move.from.row][3] = board[move.from.row][0]!.copyWith(hasMoved: true);
        board[move.from.row][0] = null;
      }
    }

    // En passant capture
    if (piece.type == PieceType.pawn &&
        enPassantTarget != null &&
        move.to == enPassantTarget) {
      final captureRow = piece.color == PieceColor.white
          ? enPassantTarget.row + 1
          : enPassantTarget.row - 1;
      board[captureRow][enPassantTarget.col] = null;
    }

    // Promotion
    if (piece.type == PieceType.pawn &&
        (move.to.row == 0 || move.to.row == 7)) {
      piece = ChessPiece(
        type:     promotion ?? PieceType.queen,
        color:    piece.color,
        hasMoved: true,
      );
    } else {
      piece = piece.copyWith(hasMoved: true);
    }

    board[move.to.row][move.to.col]     = piece;
    board[move.from.row][move.from.col] = null;
  }

  // ── Game status ───────────────────────────────────────────────────────────

  static ChessGameModel _computeStatus(ChessGameModel g) {
    final inCheck   = isInCheck(g, g.currentTurn);
    final hasLegal  = _hasAnyLegalMove(g, g.currentTurn);

    if (!hasLegal) {
      if (inCheck) return g.copyWith(status: GameStatus.checkmate);
      return g.copyWith(status: GameStatus.stalemate);
    }
    if (inCheck) return g.copyWith(status: GameStatus.check);
    return g.copyWith(status: GameStatus.active);
  }

  static bool _hasAnyLegalMove(ChessGameModel g, PieceColor color) {
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = g.board[r][c];
        if (p == null || p.color != color) continue;
        if (legalMovesFor(g, Position(r, c)).isNotEmpty) return true;
      }
    }
    return false;
  }

  // ── Insufficient material draw ────────────────────────────────────────────

  static bool isInsufficientMaterial(List<List<ChessPiece?>> board) {
    final pieces = <ChessPiece>[];
    for (final row in board) {
      for (final p in row) { if (p != null) pieces.add(p); }
    }
    if (pieces.length == 2) return true; // King vs King
    if (pieces.length == 3) {
      return pieces.any((p) =>
          p.type == PieceType.bishop || p.type == PieceType.knight);
    }
    return false;
  }

  // ── Promotion check ───────────────────────────────────────────────────────

  static bool needsPromotion(ChessGameModel g) {
    for (int c = 0; c < 8; c++) {
      final white = g.board[0][c];
      if (white != null && white.type == PieceType.pawn && white.color == PieceColor.white) return true;
      final black = g.board[7][c];
      if (black != null && black.type == PieceType.pawn && black.color == PieceColor.black) return true;
    }
    return false;
  }
}