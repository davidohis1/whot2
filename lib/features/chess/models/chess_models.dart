// ══════════════════════════════════════════════════════════════════════════════
// Chess Models
// ══════════════════════════════════════════════════════════════════════════════

enum PieceType { king, queen, rook, bishop, knight, pawn }
enum PieceColor { white, black }
enum GameStatus { waiting, active, check, checkmate, stalemate, draw, armageddon }
enum CastleSide { kingside, queenside }

class ChessPiece {
  final PieceType type;
  final PieceColor color;
  final bool hasMoved;

  const ChessPiece({
    required this.type,
    required this.color,
    this.hasMoved = false,
  });

  ChessPiece copyWith({PieceType? type, PieceColor? color, bool? hasMoved}) =>
      ChessPiece(
        type:     type     ?? this.type,
        color:    color    ?? this.color,
        hasMoved: hasMoved ?? this.hasMoved,
      );

  String get symbol {
    const symbols = {
      PieceType.king:   ['♔', '♚'],
      PieceType.queen:  ['♕', '♛'],
      PieceType.rook:   ['♖', '♜'],
      PieceType.bishop: ['♗', '♝'],
      PieceType.knight: ['♘', '♞'],
      PieceType.pawn:   ['♙', '♟'],
    };
    return symbols[type]![color == PieceColor.white ? 0 : 1];
  }

  String toFen() {
    const fenMap = {
      PieceType.king: 'k', PieceType.queen: 'q', PieceType.rook: 'r',
      PieceType.bishop: 'b', PieceType.knight: 'n', PieceType.pawn: 'p',
    };
    final ch = fenMap[type]!;
    return color == PieceColor.white ? ch.toUpperCase() : ch;
  }

  factory ChessPiece.fromFen(String ch) {
    final isWhite = ch == ch.toUpperCase();
    const map = {
      'k': PieceType.king,   'q': PieceType.queen,  'r': PieceType.rook,
      'b': PieceType.bishop, 'n': PieceType.knight, 'p': PieceType.pawn,
    };
    return ChessPiece(
      type:  map[ch.toLowerCase()]!,
      color: isWhite ? PieceColor.white : PieceColor.black,
    );
  }

  factory ChessPiece.fromMap(Map<String, dynamic> m) => ChessPiece(
    type:     PieceType.values[m['type'] as int],
    color:    PieceColor.values[m['color'] as int],
    hasMoved: m['hasMoved'] as bool? ?? false,
  );

  Map<String, dynamic> toMap() => {
    'type':     type.index,
    'color':    color.index,
    'hasMoved': hasMoved,
  };
}

class Position {
  final int row; // 0 = rank 8, 7 = rank 1
  final int col; // 0 = file a, 7 = file h

  const Position(this.row, this.col);

  bool get isValid => row >= 0 && row < 8 && col >= 0 && col < 8;

  @override
  bool operator ==(Object o) => o is Position && o.row == row && o.col == col;

  @override
  int get hashCode => row * 8 + col;

  @override
  String toString() {
    final file = String.fromCharCode('a'.codeUnitAt(0) + col);
    final rank = 8 - row;
    return '$file$rank';
  }

  factory Position.fromString(String s) {
    final col = s[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final row = 8 - int.parse(s[1]);
    return Position(row, col);
  }

  Map<String, dynamic> toMap() => {'row': row, 'col': col};
  factory Position.fromMap(Map<String, dynamic> m) =>
      Position(m['row'] as int, m['col'] as int);
}

class ChessMove {
  final Position from;
  final Position to;
  final PieceType? promoteTo;
  final bool isCastle;
  final bool isEnPassant;

  const ChessMove({
    required this.from,
    required this.to,
    this.promoteTo,
    this.isCastle = false,
    this.isEnPassant = false,
  });

  Map<String, dynamic> toMap() => {
    'from':        from.toMap(),
    'to':          to.toMap(),
    'promoteTo':   promoteTo?.index,
    'isCastle':    isCastle,
    'isEnPassant': isEnPassant,
  };

  factory ChessMove.fromMap(Map<String, dynamic> m) => ChessMove(
    from:        Position.fromMap(Map<String, dynamic>.from(m['from'] as Map)),
    to:          Position.fromMap(Map<String, dynamic>.from(m['to'] as Map)),
    promoteTo:   m['promoteTo'] != null ? PieceType.values[m['promoteTo'] as int] : null,
    isCastle:    m['isCastle'] as bool? ?? false,
    isEnPassant: m['isEnPassant'] as bool? ?? false,
  );
}

class ChessGameModel {
  final String gameId;
  final String whitePlayerId;
  final String blackPlayerId;
  final String whitePlayerName;
  final String blackPlayerName;
  final List<List<ChessPiece?>> board;
  final PieceColor currentTurn;
  final GameStatus status;
  final List<ChessMove> moveHistory;
  final Position? enPassantTarget;
  final bool whiteCanCastleKingside;
  final bool whiteCanCastleQueenside;
  final bool blackCanCastleKingside;
  final bool blackCanCastleQueenside;
  final int whiteTimeSeconds;
  final int blackTimeSeconds;
  final bool isArmageddon;
  final String? winnerId;
  final DateTime createdAt;
  final DateTime? startedAt;

  const ChessGameModel({
    required this.gameId,
    required this.whitePlayerId,
    required this.blackPlayerId,
    required this.whitePlayerName,
    required this.blackPlayerName,
    required this.board,
    required this.currentTurn,
    required this.status,
    required this.moveHistory,
    this.enPassantTarget,
    this.whiteCanCastleKingside  = true,
    this.whiteCanCastleQueenside = true,
    this.blackCanCastleKingside  = true,
    this.blackCanCastleQueenside = true,
    this.whiteTimeSeconds = 420,
    this.blackTimeSeconds = 420,
    this.isArmageddon     = false,
    this.winnerId,
    required this.createdAt,
    this.startedAt,
  });

  ChessGameModel copyWith({
    List<List<ChessPiece?>>? board,
    PieceColor? currentTurn,
    GameStatus? status,
    List<ChessMove>? moveHistory,
    Position? enPassantTarget,
    bool clearEnPassant = false,
    bool? whiteCanCastleKingside,
    bool? whiteCanCastleQueenside,
    bool? blackCanCastleKingside,
    bool? blackCanCastleQueenside,
    int? whiteTimeSeconds,
    int? blackTimeSeconds,
    bool? isArmageddon,
    String? winnerId,
    DateTime? startedAt,
  }) => ChessGameModel(
    gameId:                  gameId,
    whitePlayerId:           whitePlayerId,
    blackPlayerId:           blackPlayerId,
    whitePlayerName:         whitePlayerName,
    blackPlayerName:         blackPlayerName,
    board:                   board                   ?? this.board,
    currentTurn:             currentTurn             ?? this.currentTurn,
    status:                  status                  ?? this.status,
    moveHistory:             moveHistory             ?? this.moveHistory,
    enPassantTarget:         clearEnPassant ? null   : (enPassantTarget ?? this.enPassantTarget),
    whiteCanCastleKingside:  whiteCanCastleKingside  ?? this.whiteCanCastleKingside,
    whiteCanCastleQueenside: whiteCanCastleQueenside ?? this.whiteCanCastleQueenside,
    blackCanCastleKingside:  blackCanCastleKingside  ?? this.blackCanCastleKingside,
    blackCanCastleQueenside: blackCanCastleQueenside ?? this.blackCanCastleQueenside,
    whiteTimeSeconds:        whiteTimeSeconds        ?? this.whiteTimeSeconds,
    blackTimeSeconds:        blackTimeSeconds        ?? this.blackTimeSeconds,
    isArmageddon:            isArmageddon            ?? this.isArmageddon,
    winnerId:                winnerId                ?? this.winnerId,
    createdAt:               createdAt,
    startedAt:               startedAt               ?? this.startedAt,
  );

  // ── Serialisation ────────────────────────────────────────────────────────

  /// Flatten 8x8 board to a 64-element list (Firestore doesn't support nested arrays)
  static List<Map<String, dynamic>?> _boardToMap(List<List<ChessPiece?>> board) {
    final flat = <Map<String, dynamic>?>[];
    for (final row in board) {
      for (final piece in row) {
        flat.add(piece?.toMap());
      }
    }
    return flat;
  }

  /// Unflatten 64-element list back to 8x8 board
  static List<List<ChessPiece?>> _boardFromMap(List<dynamic> raw) {
    final board = List.generate(8, (_) => List<ChessPiece?>.filled(8, null));
    for (int i = 0; i < raw.length && i < 64; i++) {
      final cell = raw[i];
      board[i ~/ 8][i % 8] = cell == null
          ? null
          : ChessPiece.fromMap(Map<String, dynamic>.from(cell as Map));
    }
    return board;
  }

  Map<String, dynamic> toMap() => {
    'gameId':                  gameId,
    'whitePlayerId':           whitePlayerId,
    'blackPlayerId':           blackPlayerId,
    'whitePlayerName':         whitePlayerName,
    'blackPlayerName':         blackPlayerName,
    'board':                   _boardToMap(board),    'currentTurn':             currentTurn.index,
    'status':                  status.index,
    'moveHistory':             moveHistory.map((m) => m.toMap()).toList(),
    'enPassantTarget':         enPassantTarget?.toMap(),
    'whiteCanCastleKingside':  whiteCanCastleKingside,
    'whiteCanCastleQueenside': whiteCanCastleQueenside,
    'blackCanCastleKingside':  blackCanCastleKingside,
    'blackCanCastleQueenside': blackCanCastleQueenside,
    'whiteTimeSeconds':        whiteTimeSeconds,
    'blackTimeSeconds':        blackTimeSeconds,
    'isArmageddon':            isArmageddon,
    'winnerId':                winnerId,
    'createdAt':               createdAt.toIso8601String(),
    'startedAt':               startedAt?.toIso8601String(),
  };

  factory ChessGameModel.fromMap(Map<String, dynamic> m) => ChessGameModel(
    gameId:                  m['gameId'] as String,
    whitePlayerId:           m['whitePlayerId'] as String,
    blackPlayerId:           m['blackPlayerId'] as String,
    whitePlayerName:         m['whitePlayerName'] as String,
    blackPlayerName:         m['blackPlayerName'] as String,
    board:                   _boardFromMap(m['board'] as List),
    currentTurn:             PieceColor.values[m['currentTurn'] as int],
    status:                  GameStatus.values[m['status'] as int],
    moveHistory:             (m['moveHistory'] as List).map(
                               (e) => ChessMove.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
    enPassantTarget:         m['enPassantTarget'] != null
                               ? Position.fromMap(Map<String, dynamic>.from(m['enPassantTarget'] as Map))
                               : null,
    whiteCanCastleKingside:  m['whiteCanCastleKingside'] as bool? ?? true,
    whiteCanCastleQueenside: m['whiteCanCastleQueenside'] as bool? ?? true,
    blackCanCastleKingside:  m['blackCanCastleKingside'] as bool? ?? true,
    blackCanCastleQueenside: m['blackCanCastleQueenside'] as bool? ?? true,
    whiteTimeSeconds:        (m['whiteTimeSeconds'] as num).toInt(),
    blackTimeSeconds:        (m['blackTimeSeconds'] as num).toInt(),
    isArmageddon:            m['isArmageddon'] as bool? ?? false,
    winnerId:                m['winnerId'] as String?,
    createdAt:               DateTime.parse(m['createdAt'] as String),
    startedAt:               m['startedAt'] != null
                               ? DateTime.parse(m['startedAt'] as String) : null,
  );
}