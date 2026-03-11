import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/services/auth_service.dart';
import '../models/ludo_models.dart';
import 'ludo_engine.dart';

// ── Prize tables ──────────────────────────────────────────────────────────────

const _4pEntry  = 400;
const _4pWin1st = 1100;
const _4pWin2nd = 200;

const _2pEntry  = 400;
const _2pWin    = 700;   // winner takes all (both entry fees minus house cut)

// ── Providers ─────────────────────────────────────────────────────────────────

final ludoServiceProvider = Provider<LudoService>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
  return LudoService(uid);
});

/// Stream of open 4-player lobbies.
final ludoLobbyProvider = StreamProvider<List<LudoLobby>>((ref) =>
    LudoService.lobbiesStream(mode: LudoGameMode.fourPlayer));

/// Stream of open 2-player lobbies.
final ludo2pLobbyProvider = StreamProvider<List<LudoLobby>>((ref) =>
    LudoService.lobbiesStream(mode: LudoGameMode.twoPlayer));

final ludoGameProvider =
    StreamProvider.family<LudoGameModel?, String>((ref, id) =>
        LudoService.gameStream(id));

// ── Lobby model ───────────────────────────────────────────────────────────────

class LudoLobby {
  final String                            lobbyId;
  final List<({String uid, String name})> players;
  final DateTime                          createdAt;
  final LudoGameMode                      mode;

  const LudoLobby({
    required this.lobbyId,
    required this.players,
    required this.createdAt,
    required this.mode,
  });

  int get requiredPlayers => mode == LudoGameMode.twoPlayer ? 2 : 4;
  bool get isFull         => players.length >= requiredPlayers;

  factory LudoLobby.fromMap(Map<String, dynamic> m) => LudoLobby(
        lobbyId:  m['lobbyId'] as String,
        players:  (m['players'] as List).map((e) {
          final p = Map<String, dynamic>.from(e as Map);
          return (uid: p['uid'] as String, name: p['name'] as String);
        }).toList(),
        createdAt: DateTime.parse(m['createdAt'] as String),
        mode: m['mode'] != null
            ? LudoGameMode.values[m['mode'] as int]
            : LudoGameMode.fourPlayer,
      );

  Map<String, dynamic> toMap() => {
        'lobbyId':   lobbyId,
        'players':   players.map((p) => {'uid': p.uid, 'name': p.name}).toList(),
        'status':    isFull ? 'full' : 'waiting',
        'createdAt': createdAt.toIso8601String(),
        'mode':      mode.index,
      };
}

// ── Service ───────────────────────────────────────────────────────────────────

class LudoService {
  final String _uid;
  final _db = FirebaseFirestore.instance;

  LudoService(this._uid);

  // ── Streams ──────────────────────────────────────────────────────────────

  static Stream<List<LudoLobby>> lobbiesStream({
    required LudoGameMode mode,
  }) =>
      FirebaseFirestore.instance
          .collection('ludo_lobbies')
          .where('status', isEqualTo: 'waiting')
          .where('mode', isEqualTo: mode.index)
          .orderBy('createdAt')
          .snapshots()
          .map((s) =>
              s.docs.map((d) => LudoLobby.fromMap(d.data())).toList());

  static Stream<LudoGameModel?> gameStream(String id) =>
      FirebaseFirestore.instance
          .collection('ludo_games')
          .doc(id)
          .snapshots()
          .map((s) => s.exists ? LudoGameModel.fromMap(s.data()!) : null);

  // ── Join or create lobby ─────────────────────────────────────────────────

  // In ludo_service.dart, find the joinOrCreate function (around line 70)

Future<String> joinOrCreate(
    String username, LudoGameMode mode) async {
  final entry = mode == LudoGameMode.twoPlayer ? _2pEntry : _4pEntry;

  final userSnap = await _db.collection('users').doc(_uid).get();
  if (!userSnap.exists) throw Exception('User profile not found.');
  final balance  = (userSnap.data()!['coinBalance'] as num).toInt();
  if (balance < entry) throw Exception('Insufficient coins');

  // REMOVE THE .limit(5) - get ALL waiting lobbies
  final snap = await _db
      .collection('ludo_lobbies')
      .where('status', isEqualTo: 'waiting')
      .where('mode', isEqualTo: mode.index)
      .orderBy('createdAt')
      .get();  // Removed .limit(5)

  final available = snap.docs
      .where((d) => !(d.data()['players'] as List)
          .any((p) => (p as Map)['uid'] == _uid))
      .toList();

  if (available.isNotEmpty) {
    // Join existing lobby
    final lobbyRef = available.first.reference;
    final lobby    = LudoLobby.fromMap(available.first.data());
    final updated  = LudoLobby(
      lobbyId:   lobby.lobbyId,
      players:   [...lobby.players, (uid: _uid, name: username)],
      createdAt: lobby.createdAt,
      mode:      mode,
    );

    if (updated.isFull) {
      // Start game
      final gameId  = const Uuid().v4();
      final game    = LudoEngine.createGame(
          gameId: gameId, players: updated.players, mode: mode);
      final gameRef = _db.collection('ludo_games').doc(gameId);
      final batch   = _db.batch();
      batch.set(gameRef, game.toMap());
      batch.delete(lobbyRef);
      for (final p in updated.players) {
        batch.update(_db.collection('users').doc(p.uid),
            {'coinBalance': FieldValue.increment(-entry)});
      }
      await batch.commit();
      return 'game:$gameId';
    } else {
      await lobbyRef.update(updated.toMap());
      return 'lobby:${lobby.lobbyId}';
    }
  } else {
    // Create new lobby
    final lobbyId  = const Uuid().v4();
    final lobbyRef = _db.collection('ludo_lobbies').doc(lobbyId);
    final lobby    = LudoLobby(
      lobbyId:   lobbyId,
      players:   [(uid: _uid, name: username)],
      createdAt: DateTime.now(),
      mode:      mode,
    );
    await lobbyRef.set(lobby.toMap());
    return 'lobby:$lobbyId';
  }
}

  Future<void> leaveLobby(String lobbyId, String username) async {
    final ref  = _db.collection('ludo_lobbies').doc(lobbyId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final lobby = LudoLobby.fromMap(snap.data()!);
    final rem   = lobby.players.where((p) => p.uid != _uid).toList();
    if (rem.isEmpty) {
      await ref.delete();
    } else {
      await ref.update(LudoLobby(
        lobbyId:   lobbyId,
        players:   rem,
        createdAt: lobby.createdAt,
        mode:      lobby.mode,
      ).toMap());
    }
  }

  // ── Game actions ─────────────────────────────────────────────────────────

  Future<void> rollDice(String gameId, LudoGameModel game) async {
    final newGame = LudoEngine.rollDice(game);
    await _db
        .collection('ludo_games')
        .doc(gameId)
        .update(newGame.toMap());
  }

  Future<void> moveToken(
      String gameId, LudoGameModel game, int tokenId) async {
    final newGame =
        LudoEngine.moveToken(game, game.currentPlayerIndex, tokenId);

    if (newGame.status == LudoGameStatus.finished) {
      await _settleGame(gameId, newGame);
    } else {
      await _db
          .collection('ludo_games')
          .doc(gameId)
          .update(newGame.toMap());
    }
  }

  Future<void> skipTurn(String gameId, LudoGameModel game) async {
    final newGame = LudoEngine.skipTurn(game);
    await _db
        .collection('ludo_games')
        .doc(gameId)
        .update(newGame.toMap());
  }

  Future<void> updateGlobalTimer(String gameId, int seconds) async {
    await _db
        .collection('ludo_games')
        .doc(gameId)
        .update({'timeLeftSeconds': seconds});
  }

  Future<void> endByTimer(String gameId, LudoGameModel game) async {
    final rankings = LudoEngine.rankByScore(game);
    final finished =
        game.copyWith(status: LudoGameStatus.finished, rankings: rankings);
    await _settleGame(gameId, finished);
  }

  // ── Settlement ────────────────────────────────────────────────────────────

  Future<void> _settleGame(String gameId, LudoGameModel game) async {
    final batch = _db.batch();
    batch.update(
        _db.collection('ludo_games').doc(gameId), game.toMap());

    if (game.gameMode == LudoGameMode.twoPlayer) {
      _settle2p(batch, game);
    } else {
      _settle4p(batch, game);
    }

    await batch.commit();
  }

  // In ludo_service.dart, find the _settle2p function (around line 150)

void _settle2p(WriteBatch batch, LudoGameModel game) {
  for (int i = 0; i < game.rankings.length; i++) {
    final uid = game.rankings[i];
    if (i == 0) {
      // Winner gets 700 coins
      batch.update(_db.collection('users').doc(uid), {
        'coinBalance': FieldValue.increment(_2pWin),  // _2pWin = 700
        'ludoWins':    FieldValue.increment(1),
      });
    } else {
      // Loser gets nothing (no coin update, just record the loss)
      batch.update(_db.collection('users').doc(uid), {
        'ludoLosses': FieldValue.increment(1),
        // No coinBalance update - they don't win anything
      });
    }
  }
}

  void _settle4p(WriteBatch batch, LudoGameModel game) {
    for (int i = 0; i < game.rankings.length; i++) {
      final uid = game.rankings[i];
      if (i == 0) {
        batch.update(_db.collection('users').doc(uid), {
          'coinBalance': FieldValue.increment(_4pWin1st),
          'ludoWins':    FieldValue.increment(1),
        });
      } else if (i == 1) {
        batch.update(_db.collection('users').doc(uid), {
          'coinBalance': FieldValue.increment(_4pWin2nd),
          'ludoLosses':  FieldValue.increment(1),
        });
      } else {
        batch.update(_db.collection('users').doc(uid),
            {'ludoLosses': FieldValue.increment(1)});
      }
    }
  }
}