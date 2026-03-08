import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/services/auth_service.dart';
import '../models/chess_models.dart';
import 'chess_engine.dart';

const _entryCost = 400;
const _winReward = 700;

// ── Providers ─────────────────────────────────────────────────────────────────

final chessServiceProvider = Provider<ChessService>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
  return ChessService(uid);
});

final chessLobbyProvider = StreamProvider<List<ChessLobby>>((ref) {
  return ChessService.lobbiesStream();
});

final chessGameProvider = StreamProvider.family<ChessGameModel?, String>((ref, id) {
  return ChessService.gameStream(id);
});

// ── Lobby model ───────────────────────────────────────────────────────────────

class ChessLobby {
  final String lobbyId;
  final String creatorId;
  final String creatorName;
  final String status; // 'waiting' | 'full'
  final DateTime createdAt;

  const ChessLobby({
    required this.lobbyId,
    required this.creatorId,
    required this.creatorName,
    required this.status,
    required this.createdAt,
  });

  factory ChessLobby.fromMap(Map<String, dynamic> m) => ChessLobby(
    lobbyId:     m['lobbyId'] as String,
    creatorId:   m['creatorId'] as String,
    creatorName: m['creatorName'] as String,
    status:      m['status'] as String,
    createdAt:   DateTime.parse(m['createdAt'] as String),
  );

  Map<String, dynamic> toMap() => {
    'lobbyId':     lobbyId,
    'creatorId':   creatorId,
    'creatorName': creatorName,
    'status':      status,
    'createdAt':   createdAt.toIso8601String(),
  };
}

// ── Service ───────────────────────────────────────────────────────────────────

class ChessService {
  final String _uid;
  final _db = FirebaseFirestore.instance;

  ChessService(this._uid);

  static Stream<List<ChessLobby>> lobbiesStream() => FirebaseFirestore.instance
      .collection('chess_lobbies')
      .where('status', isEqualTo: 'waiting')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((s) => s.docs.map((d) => ChessLobby.fromMap(d.data())).toList());

  static Stream<ChessGameModel?> gameStream(String id) => FirebaseFirestore.instance
      .collection('chess_games')
      .doc(id)
      .snapshots()
      .map((s) => s.exists ? ChessGameModel.fromMap(s.data()!) : null);

  Future<String> createOrJoinLobby(String username) async {
    // Check balance first — outside transaction to avoid contention
    final userSnap = await _db.collection('users').doc(_uid).get();
    if (!userSnap.exists) throw Exception('User profile not found. Please restart the app.');
    final balance = (userSnap.data()!['coinBalance'] as num).toInt();
    if (balance < _entryCost) throw Exception('Insufficient coins');

    // Look for an open lobby — no orderBy to avoid index requirement
    final lobbies = await _db
        .collection('chess_lobbies')
        .where('status', isEqualTo: 'waiting')
        .limit(5)
        .get();

    // Filter out own lobby
    final available = lobbies.docs
        .where((d) => d.data()['creatorId'] != _uid)
        .toList();

    if (available.isNotEmpty) {
      // Join the first available lobby and start a game
      final lobbyDoc = available.first;
      final lobby    = ChessLobby.fromMap(lobbyDoc.data());

      final gameId    = const Uuid().v4();
      final isWhite   = DateTime.now().millisecondsSinceEpoch % 2 == 0;
      final whiteId   = isWhite ? _uid          : lobby.creatorId;
      final blackId   = isWhite ? lobby.creatorId : _uid;
      final whiteName = isWhite ? username        : lobby.creatorName;
      final blackName = isWhite ? lobby.creatorName : username;

      final game = ChessGameModel(
        gameId:           gameId,
        whitePlayerId:    whiteId,
        blackPlayerId:    blackId,
        whitePlayerName:  whiteName,
        blackPlayerName:  blackName,
        board:            ChessEngine.createInitialBoard(),
        currentTurn:      PieceColor.white,
        status:           GameStatus.active,
        moveHistory:      [],
        whiteTimeSeconds: 420,
        blackTimeSeconds: 420,
        createdAt:        DateTime.now(),
        startedAt:        DateTime.now(),
      );

      final batch = _db.batch();
      batch.set(_db.collection('chess_games').doc(gameId), game.toMap());
      batch.delete(_db.collection('chess_lobbies').doc(lobby.lobbyId));
      batch.update(_db.collection('users').doc(_uid),
          {'coinBalance': FieldValue.increment(-_entryCost)});
      batch.update(_db.collection('users').doc(lobby.creatorId),
          {'coinBalance': FieldValue.increment(-_entryCost)});
      await batch.commit();

      return 'game:$gameId';
    } else {
      // No open lobby — create one
      final lobbyId = const Uuid().v4();
      final lobby   = ChessLobby(
        lobbyId:     lobbyId,
        creatorId:   _uid,
        creatorName: username,
        status:      'waiting',
        createdAt:   DateTime.now(),
      );
      await _db.collection('chess_lobbies').doc(lobbyId).set(lobby.toMap());
      return 'lobby:$lobbyId';
    }
  }

  Future<void> leaveLobby(String lobbyId) async {
    await _db.collection('chess_lobbies').doc(lobbyId).delete();
  }

  Future<void> makeMove(String gameId, ChessGameModel currentGame, ChessMove move,
      {PieceType? promotion}) async {
    final newGame = ChessEngine.applyMove(currentGame, move, promotion: promotion);
    final updates = newGame.toMap();

    // Handle end states
    if (newGame.status == GameStatus.checkmate) {
      final winnerId = newGame.currentTurn == PieceColor.white
          ? newGame.blackPlayerId
          : newGame.whitePlayerId;
      final loserId  = winnerId == newGame.whitePlayerId
          ? newGame.blackPlayerId
          : newGame.whitePlayerId;

      updates['winnerId'] = winnerId;

      final batch = _db.batch();
      batch.update(_db.collection('chess_games').doc(gameId), updates);
      batch.update(_db.collection('users').doc(winnerId), {
        'coinBalance': FieldValue.increment(_winReward),
        'chessWins':   FieldValue.increment(1),
      });
      batch.update(_db.collection('users').doc(loserId), {
        'chessLosses': FieldValue.increment(1),
      });
      await batch.commit();
    } else {
      await _db.collection('chess_games').doc(gameId).update(updates);
    }
  }

  Future<void> updateTimer(String gameId, PieceColor turn, int seconds) async {
    final field = turn == PieceColor.white ? 'whiteTimeSeconds' : 'blackTimeSeconds';
    await _db.collection('chess_games').doc(gameId).update({field: seconds});
  }

  Future<void> flagOnTimeout(String gameId, ChessGameModel game, PieceColor loserColor) async {
    final winnerId = loserColor == PieceColor.white
        ? game.blackPlayerId
        : game.whitePlayerId;
    final loserId  = loserColor == PieceColor.white
        ? game.whitePlayerId
        : game.blackPlayerId;

    final batch = _db.batch();
    batch.update(_db.collection('chess_games').doc(gameId), {
      'status':   GameStatus.checkmate.index,
      'winnerId': winnerId,
    });
    batch.update(_db.collection('users').doc(winnerId), {
      'coinBalance': FieldValue.increment(_winReward),
      'chessWins':   FieldValue.increment(1),
    });
    batch.update(_db.collection('users').doc(loserId), {
      'chessLosses': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Future<void> startArmageddon(String gameId, ChessGameModel game) async {
    final updates = game.copyWith(
      isArmageddon:     true,
      status:           GameStatus.armageddon,
      whiteTimeSeconds: 300, // 5 min for white
      blackTimeSeconds: 240, // 4 min for black
      board:            ChessEngine.createInitialBoard(),
      currentTurn:      PieceColor.white,
      moveHistory:      [],
    ).toMap();
    await _db.collection('chess_games').doc(gameId).update(updates);
  }

  Future<void> claimDraw(String gameId, ChessGameModel game) async {
    // Called after armageddon stalemate — black wins draw odds
    final winnerId = game.blackPlayerId;
    final loserId  = game.whitePlayerId;
    final batch    = _db.batch();
    batch.update(_db.collection('chess_games').doc(gameId), {
      'status':   GameStatus.draw.index,
      'winnerId': winnerId,
    });
    batch.update(_db.collection('users').doc(winnerId), {
      'coinBalance': FieldValue.increment(_winReward),
      'chessWins':   FieldValue.increment(1),
    });
    batch.update(_db.collection('users').doc(loserId), {
      'chessLosses': FieldValue.increment(1),
    });
    await batch.commit();
  }
}