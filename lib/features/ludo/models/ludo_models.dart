// ══════════════════════════════════════════════════════════════════════════════
// Ludo Models  –  supports 2-player and 4-player modes
// ══════════════════════════════════════════════════════════════════════════════

enum LudoColor { red, green, yellow, blue }

enum LudoGameStatus { waiting, active, finished }

/// How many human players are in this game.
enum LudoGameMode { twoPlayer, fourPlayer }

// ── Safe squares on the main track (0-indexed, 52 total squares) ─────────────
const safeSquares = {0, 8, 13, 21, 26, 34, 39, 47};

// ── Starting positions on main track per color ────────────────────────────────
const colorStartSquare = {
  LudoColor.red:    0,
  LudoColor.green:  13,
  LudoColor.yellow: 26,
  LudoColor.blue:   39,
};

// ── Home column entry square (last main-track square before home col) ─────────
const colorHomeEntry = {
  LudoColor.red:    50,
  LudoColor.green:  11,
  LudoColor.yellow: 24,
  LudoColor.blue:   37,
};

class LudoToken {
  final int       id;           // 0-3 within a player
  final LudoColor color;
  final int       trackPos;     // -1=base, 0-51=main track, 100-105=home col
  final bool      isHome;       // reached final home triangle
  final int       totalRolled;  // cumulative dice rolls that moved this token

  const LudoToken({
    required this.id,
    required this.color,
    this.trackPos    = -1,
    this.isHome      = false,
    this.totalRolled = 0,
  });

  bool get isInBase    => trackPos == -1;
  bool get isOnTrack   => trackPos >= 0 && trackPos <= 51 && !isHome;
  bool get isInHomeCol => trackPos >= 100 && !isHome;

  LudoToken copyWith({
    int?  trackPos,
    bool? isHome,
    int?  totalRolled,
  }) =>
      LudoToken(
        id:          id,
        color:       color,
        trackPos:    trackPos    ?? this.trackPos,
        isHome:      isHome      ?? this.isHome,
        totalRolled: totalRolled ?? this.totalRolled,
      );

  Map<String, dynamic> toMap() => {
        'id':          id,
        'color':       color.index,
        'trackPos':    trackPos,
        'isHome':      isHome,
        'totalRolled': totalRolled,
      };

  factory LudoToken.fromMap(Map<String, dynamic> m) => LudoToken(
        id:          m['id']          as int,
        color:       LudoColor.values[m['color'] as int],
        trackPos:    m['trackPos']    as int,
        isHome:      m['isHome']      as bool,
        totalRolled: m['totalRolled'] as int? ?? 0,
      );
}

class LudoPlayer {
  final String          uid;
  final String          name;
  final LudoColor       color;
  final List<LudoToken> tokens;
  final int             score;
  final int             position; // 0-3 turn order

  const LudoPlayer({
    required this.uid,
    required this.name,
    required this.color,
    required this.tokens,
    required this.score,
    required this.position,
  });

  bool get allHome => tokens.every((t) => t.isHome);

  LudoPlayer copyWith({
    List<LudoToken>? tokens,
    int?             score,
  }) =>
      LudoPlayer(
        uid:      uid,
        name:     name,
        color:    color,
        tokens:   tokens ?? this.tokens,
        score:    score  ?? this.score,
        position: position,
      );

  Map<String, dynamic> toMap() => {
        'uid':      uid,
        'name':     name,
        'color':    color.index,
        'tokens':   tokens.map((t) => t.toMap()).toList(),
        'score':    score,
        'position': position,
      };

  factory LudoPlayer.fromMap(Map<String, dynamic> m) => LudoPlayer(
        uid:      m['uid']  as String,
        name:     m['name'] as String,
        color:    LudoColor.values[m['color'] as int],
        tokens:   (m['tokens'] as List)
            .map((e) =>
                LudoToken.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        score:    m['score']    as int? ?? 0,
        position: m['position'] as int,
      );
}

class LudoGameModel {
  final String           gameId;
  final List<LudoPlayer> players;
  final int              currentPlayerIndex;
  final int?             diceValue;        // null = not rolled yet
  final bool             diceRolled;
  final bool             extraTurn;        // true if rolled a 6 or captured
  final int              consecutiveSixes;
  final LudoGameStatus   status;
  final List<String>     rankings;         // uids in finish order
  final DateTime         createdAt;
  final DateTime?        startedAt;
  final int              timeLeftSeconds;
  final int              turnTimeLeft;     // 10 s per turn
  final LudoGameMode     gameMode;

  const LudoGameModel({
    required this.gameId,
    required this.players,
    required this.currentPlayerIndex,
    this.diceValue,
    this.diceRolled       = false,
    this.extraTurn        = false,
    this.consecutiveSixes = 0,
    required this.status,
    required this.rankings,
    required this.createdAt,
    this.startedAt,
    this.timeLeftSeconds  = 420,
    this.turnTimeLeft     = 10,
    this.gameMode         = LudoGameMode.fourPlayer,
  });

  LudoPlayer get currentPlayer => players[currentPlayerIndex];

  LudoGameModel copyWith({
    List<LudoPlayer>? players,
    int?              currentPlayerIndex,
    int?              diceValue,
    bool              clearDiceValue = false,
    bool?             diceRolled,
    bool?             extraTurn,
    int?              consecutiveSixes,
    LudoGameStatus?   status,
    List<String>?     rankings,
    DateTime?         startedAt,
    int?              timeLeftSeconds,
    int?              turnTimeLeft,
    LudoGameMode?     gameMode,
  }) =>
      LudoGameModel(
        gameId:             gameId,
        players:            players            ?? this.players,
        currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
        diceValue:          clearDiceValue ? null : (diceValue ?? this.diceValue),
        diceRolled:         diceRolled         ?? this.diceRolled,
        extraTurn:          extraTurn          ?? this.extraTurn,
        consecutiveSixes:   consecutiveSixes   ?? this.consecutiveSixes,
        status:             status             ?? this.status,
        rankings:           rankings           ?? this.rankings,
        createdAt:          createdAt,
        startedAt:          startedAt          ?? this.startedAt,
        timeLeftSeconds:    timeLeftSeconds    ?? this.timeLeftSeconds,
        turnTimeLeft:       turnTimeLeft       ?? this.turnTimeLeft,
        gameMode:           gameMode           ?? this.gameMode,
      );

  Map<String, dynamic> toMap() => {
        'gameId':             gameId,
        'players':            players.map((p) => p.toMap()).toList(),
        'currentPlayerIndex': currentPlayerIndex,
        'diceValue':          diceValue,
        'diceRolled':         diceRolled,
        'extraTurn':          extraTurn,
        'consecutiveSixes':   consecutiveSixes,
        'status':             status.index,
        'rankings':           rankings,
        'createdAt':          createdAt.toIso8601String(),
        'startedAt':          startedAt?.toIso8601String(),
        'timeLeftSeconds':    timeLeftSeconds,
        'turnTimeLeft':       turnTimeLeft,
        'gameMode':           gameMode.index,
      };

  factory LudoGameModel.fromMap(Map<String, dynamic> m) => LudoGameModel(
        gameId:             m['gameId']   as String,
        players:            (m['players'] as List)
            .map((e) =>
                LudoPlayer.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        currentPlayerIndex: m['currentPlayerIndex'] as int,
        diceValue:          m['diceValue']  as int?,
        diceRolled:         m['diceRolled'] as bool? ?? false,
        extraTurn:          m['extraTurn']  as bool? ?? false,
        consecutiveSixes:   m['consecutiveSixes'] as int? ?? 0,
        status:             LudoGameStatus.values[m['status'] as int],
        rankings:           List<String>.from(m['rankings'] as List),
        createdAt:          DateTime.parse(m['createdAt'] as String),
        startedAt:          m['startedAt'] != null
            ? DateTime.parse(m['startedAt'] as String)
            : null,
        timeLeftSeconds: m['timeLeftSeconds'] as int? ?? 420,
        turnTimeLeft:    m['turnTimeLeft']    as int? ?? 10,
        gameMode:        m['gameMode'] != null
            ? LudoGameMode.values[m['gameMode'] as int]
            : LudoGameMode.fourPlayer,
      );
}