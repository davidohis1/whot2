import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/services/auth_service.dart';
import '../models/whot_models.dart';
import 'whot_engine.dart';

const _whotEntry    = 400;
const _whotWin1st   = 1000;
const _whotWin2nd   = 300;

// ── Providers ─────────────────────────────────────────────────────────────────

final whotServiceProvider = Provider<WhotService>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
  return WhotService(uid);
});

final whotLobbyProvider = StreamProvider<List<WhotLobby>>((ref) {
  return WhotService.lobbiesStream();
});

final whotGameProvider = StreamProvider.family<WhotGameModel?, String>((ref, id) {
  return WhotService.gameStream(id);
});

// ── Lobby ─────────────────────────────────────────────────────────────────────

class WhotLobby {
  final String lobbyId;
  final List<({String uid, String name})> players;
  final DateTime createdAt;

  const WhotLobby({
    required this.lobbyId,
    required this.players,
    required this.createdAt,
  });

  bool get isFull => players.length >= 4;

  factory WhotLobby.fromMap(Map<String, dynamic> m) => WhotLobby(
    lobbyId: m['lobbyId'] as String,
    players: (m['players'] as List).map((e) {
      final p = Map<String, dynamic>.from(e as Map);
      return (uid: p['uid'] as String, name: p['name'] as String);
    }).toList(),
    createdAt: DateTime.parse(m['createdAt'] as String),
  );

  Map<String, dynamic> toMap() => {
    'lobbyId':  lobbyId,
    'players':  players.map((p) => {'uid': p.uid, 'name': p.name}).toList(),
    'status':   isFull ? 'full' : 'waiting',
    'createdAt': createdAt.toIso8601String(),
  };
}

// ── Service ───────────────────────────────────────────────────────────────────

class WhotService {
  final String _uid;
  final _db = FirebaseFirestore.instance;

  WhotService(this._uid);

  static Stream<List<WhotLobby>> lobbiesStream() => FirebaseFirestore.instance
      .collection('whot_lobbies')
      .where('status', isEqualTo: 'waiting')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map((d) => WhotLobby.fromMap(d.data())).toList());

  static Stream<WhotGameModel?> gameStream(String id) => FirebaseFirestore.instance
      .collection('whot_games')
      .doc(id)
      .snapshots()
      .map((s) => s.exists ? WhotGameModel.fromMap(s.data()!) : null);

  /// Returns 'lobby:<id>' or 'game:<id>'
  Future<String> joinOrCreate(String username) async {
    return _db.runTransaction<String>((tx) async {
      final userRef  = _db.collection('users').doc(_uid);
      final userSnap = await tx.get(userRef);
      final balance  = (userSnap.data()!['coinBalance'] as num).toInt();
      if (balance < _whotEntry) throw Exception('Insufficient coins');

      // Look for open lobby
      final snap = await _db.collection('whot_lobbies')
          .where('status', isEqualTo: 'waiting')
          .orderBy('createdAt')
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final lobbyRef = snap.docs.first.reference;
        final lobby    = WhotLobby.fromMap(snap.docs.first.data());

        // Already in lobby?
        if (lobby.players.any((p) => p.uid == _uid)) {
          return 'lobby:${lobby.lobbyId}';
        }

        final updated = WhotLobby(
          lobbyId:   lobby.lobbyId,
          players:   [...lobby.players, (uid: _uid, name: username)],
          createdAt: lobby.createdAt,
        );

        if (updated.isFull) {
          // Start game
          final gameId  = const Uuid().v4();
          final game    = WhotEngine.createGame(gameId: gameId, players: updated.players);
          final gameRef = _db.collection('whot_games').doc(gameId);

          tx.set(gameRef, game.toMap());
          tx.delete(lobbyRef);

          // Deduct entry from all 4
          for (final p in updated.players) {
            tx.update(_db.collection('users').doc(p.uid),
                {'coinBalance': FieldValue.increment(-_whotEntry)});
          }
          return 'game:$gameId';
        } else {
          tx.update(lobbyRef, updated.toMap());
          return 'lobby:${lobby.lobbyId}';
        }
      } else {
        // Create lobby
        final lobbyId  = const Uuid().v4();
        final lobbyRef = _db.collection('whot_lobbies').doc(lobbyId);
        final lobby    = WhotLobby(
          lobbyId:  lobbyId,
          players:  [(uid: _uid, name: username)],
          createdAt: DateTime.now(),
        );
        tx.set(lobbyRef, lobby.toMap());
        return 'lobby:$lobbyId';
      }
    });
  }

  Future<void> leaveLobby(String lobbyId, String username) async {
    final ref  = _db.collection('whot_lobbies').doc(lobbyId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final lobby = WhotLobby.fromMap(snap.data()!);
    final remaining = lobby.players.where((p) => p.uid != _uid).toList();
    if (remaining.isEmpty) {
      await ref.delete();
    } else {
      await ref.update(WhotLobby(
        lobbyId: lobbyId, players: remaining, createdAt: lobby.createdAt).toMap());
    }
  }

  Future<void> playCard(
    String gameId,
    WhotGameModel currentGame,
    WhotCard card, {
    WhotShape? calledShape,
    required bool declaredLastCard,
  }) async {
    var newGame = WhotEngine.playCard(currentGame, card, calledShape: calledShape);

    // Update declared last card flag
    final pi = currentGame.currentPlayerIndex;
    final players = List<WhotPlayer>.from(newGame.players);
    if (players[pi].hand.length == 1) {
      players[pi] = players[pi].copyWith(declaredLastCard: declaredLastCard);
    } else {
      players[pi] = players[pi].copyWith(declaredLastCard: false);
    }
    newGame = newGame.copyWith(players: players);

    if (newGame.status == WhotGameStatus.finished) {
      await _settleGame(gameId, newGame);
    } else {
      await _db.collection('whot_games').doc(gameId).update(newGame.toMap());
    }
  }

  Future<void> drawCard(String gameId, WhotGameModel game, {int count = 1}) async {
    final newGame = WhotEngine.drawFromMarket(game, count: count);
    await _db.collection('whot_games').doc(gameId).update(newGame.toMap());
  }

  Future<void> penaliseLastCard(String gameId, WhotGameModel game, String targetUid) async {
    // Find player index
    final pi = game.players.indexWhere((p) => p.uid == targetUid);
    if (pi < 0) return;
    var updated = WhotEngine.drawFromMarket(
      game.copyWith(currentPlayerIndex: pi), count: 2);
    // Restore turn
    updated = updated.copyWith(currentPlayerIndex: game.currentPlayerIndex);
    await _db.collection('whot_games').doc(gameId).update(updated.toMap());
  }

  Future<void> updateGlobalTimer(String gameId, int seconds) async {
    await _db.collection('whot_games')
        .doc(gameId)
        .update({'timeLeftSeconds': seconds});
  }

  Future<void> skipTurn(String gameId, WhotGameModel game) async {
    final newGame = WhotEngine.skipTurn(game);
    await _db.collection('whot_games').doc(gameId).update(newGame.toMap());
  }

  Future<void> endByTimer(String gameId, WhotGameModel game) async {
    final finalRankings = WhotEngine.rankByCardCount(game);
    final finished = game.copyWith(status: WhotGameStatus.finished, rankings: finalRankings);
    await _settleGame(gameId, finished);
  }

  Future<void> _settleGame(String gameId, WhotGameModel game) async {
    final batch = _db.batch();
    batch.update(_db.collection('whot_games').doc(gameId), game.toMap());

    for (int i = 0; i < game.rankings.length; i++) {
      final uid = game.rankings[i];
      if (i == 0) {
        batch.update(_db.collection('users').doc(uid), {
          'coinBalance': FieldValue.increment(_whotWin1st),
          'whotWins':    FieldValue.increment(1),
        });
      } else if (i == 1) {
        batch.update(_db.collection('users').doc(uid), {
          'coinBalance': FieldValue.increment(_whotWin2nd),
          'whotLosses':  FieldValue.increment(1),
        });
      } else {
        batch.update(_db.collection('users').doc(uid), {
          'whotLosses': FieldValue.increment(1),
        });
      }
    }
    await batch.commit();
  }
}