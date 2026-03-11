// ══════════════════════════════════════════════════════════════════════════════
// Whot Models
// ══════════════════════════════════════════════════════════════════════════════

enum WhotShape { circle, triangle, cross, square, star, whot }

class WhotCard {
  final WhotShape shape;
  final int       number; // 20 = whot card

  const WhotCard({required this.shape, required this.number});

  bool get isWhot => shape == WhotShape.whot;

  /// Can this card be played on top of [topCard] given [calledShape]?
  bool canPlayOn(WhotCard topCard, {WhotShape? calledShape}) {
    if (isWhot) return true;
    if (topCard.isWhot) {
      // Must match called shape
      return calledShape != null && shape == calledShape;
    }
    return shape == topCard.shape || number == topCard.number;
  }

  String get shapeName {
    const names = {
      WhotShape.circle:   'Circle',
      WhotShape.triangle: 'Triangle',
      WhotShape.cross:    'Cross',
      WhotShape.square:   'Square',
      WhotShape.star:     'Star',
      WhotShape.whot:     'Whot',
    };
    return names[shape]!;
  }

  String get shapeEmoji {
    const e = {
      WhotShape.circle:   '⭕',
      WhotShape.triangle: '▲',
      WhotShape.cross:    '✖',
      WhotShape.square:   '■',
      WhotShape.star:     '★',
      WhotShape.whot:     '🌟',
    };
    return e[shape]!;
  }

  @override
  String toString() => isWhot ? 'Whot 20' : '${shapeName} $number';

  Map<String, dynamic> toMap() => {'shape': shape.index, 'number': number};

  factory WhotCard.fromMap(Map<String, dynamic> m) => WhotCard(
    shape:  WhotShape.values[m['shape'] as int],
    number: m['number'] as int,
  );

  @override
  bool operator ==(Object o) =>
      o is WhotCard && o.shape == shape && o.number == number;

  @override
  int get hashCode => shape.index * 100 + number;
}

// ── Full 54-card deck ─────────────────────────────────────────────────────────

List<WhotCard> buildWhotDeck() {
  final deck = <WhotCard>[];
  const validNumbers = [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14]; // no 9

  for (int n in validNumbers) deck.add(WhotCard(shape: WhotShape.circle,   number: n));
  for (int n in validNumbers) deck.add(WhotCard(shape: WhotShape.triangle, number: n));
  for (int n in validNumbers) deck.add(WhotCard(shape: WhotShape.cross,    number: n));
  for (int n in validNumbers) deck.add(WhotCard(shape: WhotShape.square,   number: n));
  // Stars: 1-8 only (no 9 anyway)
  for (int n = 1; n <= 8; n++) deck.add(WhotCard(shape: WhotShape.star,   number: n));
  // Whot (20) cards × 4
  for (int i = 0; i < 4; i++)  deck.add(WhotCard(shape: WhotShape.whot,   number: 20));

  return deck;
}

// ── Game State ────────────────────────────────────────────────────────────────

enum WhotGameStatus { waiting, active, finished }
enum WhotActionPending { none, pickTwo, pickThree, suspension }

class WhotPlayer {
  final String uid;
  final String name;
  final List<WhotCard> hand;
  final bool  declaredLastCard;
  final int   position; // 0-3

  const WhotPlayer({
    required this.uid,
    required this.name,
    required this.hand,
    required this.position,
    this.declaredLastCard = false,
  });

  WhotPlayer copyWith({
    List<WhotCard>? hand,
    bool? declaredLastCard,
  }) => WhotPlayer(
    uid:              uid,
    name:             name,
    hand:             hand             ?? this.hand,
    position:         position,
    declaredLastCard: declaredLastCard ?? this.declaredLastCard,
  );

  Map<String, dynamic> toMap() => {
    'uid':              uid,
    'name':             name,
    'hand':             hand.map((c) => c.toMap()).toList(),
    'position':         position,
    'declaredLastCard': declaredLastCard,
  };

  factory WhotPlayer.fromMap(Map<String, dynamic> m) => WhotPlayer(
    uid:              m['uid']  as String,
    name:             m['name'] as String,
    hand:             (m['hand'] as List)
                        .map((e) => WhotCard.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
    position:         m['position'] as int,
    declaredLastCard: m['declaredLastCard'] as bool? ?? false,
  );
}

class WhotGameModel {
  final String           gameId;
  final List<WhotPlayer> players;        // ordered 0-3
  final List<WhotCard>   market;         // draw pile
  final List<WhotCard>   pile;           // discard pile
  final int              currentPlayerIndex;
  final WhotShape?       calledShape;    // shape called after Whot 20
  final WhotActionPending pending;
  final int              pendingCount;   // cards to draw
  final WhotGameStatus   status;
  final List<String>     rankings;       // uids in finish order
  final DateTime         createdAt;
  final DateTime?        startedAt;
  final int              timeLeftSeconds;
  final int playerCount; // 2 or 4
  final int              turnTimeLeft;   // 10-second per-turn countdown
  

  const WhotGameModel({
    required this.gameId,
    required this.players,
    required this.market,
    required this.pile,
    required this.currentPlayerIndex,
    this.calledShape,
    this.pending      = WhotActionPending.none,
    this.pendingCount = 0,
    required this.status,
    required this.rankings,
    required this.createdAt,
    this.startedAt,
    this.timeLeftSeconds = 420,
    this.turnTimeLeft    = 10,
    this.playerCount = 4,
  });

  WhotPlayer get currentPlayer => players[currentPlayerIndex];

  WhotCard get topCard => pile.last;

  WhotGameModel copyWith({
    List<WhotPlayer>?     players,
    List<WhotCard>?       market,
    List<WhotCard>?       pile,
    int?                  currentPlayerIndex,
    WhotShape?            calledShape,
    bool                  clearCalledShape = false,
    WhotActionPending?    pending,
    int?                  pendingCount,
    WhotGameStatus?       status,
    List<String>?         rankings,
    DateTime?             startedAt,
    int?                  timeLeftSeconds,
    int?                  turnTimeLeft,
    int?                  playerCount,
  }) => WhotGameModel(
    gameId:             gameId,
    players:            players            ?? this.players,
    market:             market             ?? this.market,
    pile:               pile               ?? this.pile,
    currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
    calledShape:        clearCalledShape ? null : (calledShape ?? this.calledShape),
    pending:            pending            ?? this.pending,
    pendingCount:       pendingCount       ?? this.pendingCount,
    status:             status             ?? this.status,
    rankings:           rankings           ?? this.rankings,
    createdAt:          createdAt,
    startedAt:          startedAt          ?? this.startedAt,
    timeLeftSeconds:    timeLeftSeconds    ?? this.timeLeftSeconds,
    turnTimeLeft:       turnTimeLeft       ?? this.turnTimeLeft,
    playerCount:        playerCount        ?? this.playerCount,
  );

  Map<String, dynamic> toMap() => {
    'gameId':             gameId,
    'players':            players.map((p) => p.toMap()).toList(),
    'market':             market.map((c) => c.toMap()).toList(),
    'pile':               pile.map((c) => c.toMap()).toList(),
    'currentPlayerIndex': currentPlayerIndex,
    'calledShape':        calledShape?.index,
    'pending':            pending.index,
    'pendingCount':       pendingCount,
    'status':             status.index,
    'rankings':           rankings,
    'createdAt':          createdAt.toIso8601String(),
    'startedAt':          startedAt?.toIso8601String(),
    'timeLeftSeconds':    timeLeftSeconds,
    'turnTimeLeft':       turnTimeLeft,
    'playerCount':        playerCount,
  };

  factory WhotGameModel.fromMap(Map<String, dynamic> m) => WhotGameModel(
    gameId:             m['gameId'] as String,
    players:            (m['players'] as List)
                          .map((e) => WhotPlayer.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
    market:             (m['market'] as List)
                          .map((e) => WhotCard.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
    pile:               (m['pile'] as List)
                          .map((e) => WhotCard.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
    currentPlayerIndex: m['currentPlayerIndex'] as int,
    calledShape:        m['calledShape'] != null
                          ? WhotShape.values[m['calledShape'] as int] : null,
    pending:            WhotActionPending.values[m['pending'] as int],
    pendingCount:       (m['pendingCount'] as num).toInt(),
    status:             WhotGameStatus.values[m['status'] as int],
    rankings:           List<String>.from(m['rankings'] as List),
    createdAt:          DateTime.parse(m['createdAt'] as String),
    startedAt:          m['startedAt'] != null ? DateTime.parse(m['startedAt'] as String) : null,
    timeLeftSeconds:    (m['timeLeftSeconds'] as num? ?? 420).toInt(),
    turnTimeLeft:       (m['turnTimeLeft']    as num? ?? 10).toInt(),
    playerCount:        (m['playerCount']     as num? ?? 4).toInt(),
  );
}