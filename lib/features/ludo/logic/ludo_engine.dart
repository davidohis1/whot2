import 'dart:math';
import '../models/ludo_models.dart';

class LudoEngine {
  static final _rng = Random.secure();

  static const int _homeColEntry = 100;
  static const int _homeColFinal = 105;

  // ── Create game ────────────────────────────────────────────────────────────
  static LudoGameModel createGame({
    required String                             gameId,
    required List<({String uid, String name})> players,
    LudoGameMode                                mode = LudoGameMode.fourPlayer,
  }) {
    assert(players.length == 2 || players.length == 4);

    // 2-player uses Red vs Yellow (opposite corners for fairer paths).
    // 4-player uses all four colors in order.
    final colors = mode == LudoGameMode.twoPlayer
        ? [LudoColor.red, LudoColor.yellow]
        : [LudoColor.red, LudoColor.green, LudoColor.yellow, LudoColor.blue];

    final gamePlayers = List.generate(
      players.length,
      (i) => LudoPlayer(
        uid:      players[i].uid,
        name:     players[i].name,
        color:    colors[i],
        tokens:   List.generate(4, (j) => LudoToken(id: j, color: colors[i])),
        score:    0,
        position: i,
      ),
    );

    return LudoGameModel(
      gameId:             gameId,
      players:            gamePlayers,
      currentPlayerIndex: 0,
      diceRolled:         false,
      status:             LudoGameStatus.active,
      rankings:           [],
      createdAt:          DateTime.now(),
      startedAt:          DateTime.now(),
      timeLeftSeconds:    420,
      turnTimeLeft:       10,
      gameMode:           mode,
    );
  }

  // ── Roll dice ──────────────────────────────────────────────────────────────
  static LudoGameModel rollDice(LudoGameModel game) {
    if (game.diceRolled) return game; // already rolled this turn

    final roll = _rng.nextInt(6) + 1;
    final p    = game.players[game.currentPlayerIndex];

    // Three sixes in a row → forfeit turn
    if (roll == 6 && game.consecutiveSixes >= 2) {
      return _advanceTurn(game.copyWith(
        diceValue:        roll,
        diceRolled:       true,
        consecutiveSixes: 0,
      ));
    }

    final newSixes = roll == 6 ? game.consecutiveSixes + 1 : 0;
    final movable  = _movableTokens(p, roll, game.players);

    // No legal moves → auto-advance turn
    if (movable.isEmpty) {
      return _advanceTurn(game.copyWith(
        diceValue:        roll,
        diceRolled:       true,
        consecutiveSixes: newSixes,
        turnTimeLeft:     10,
      ));
    }

    return game.copyWith(
      diceValue:        roll,
      diceRolled:       true,
      consecutiveSixes: newSixes,
      turnTimeLeft:     10,
    );
  }

  // ── Move a token ───────────────────────────────────────────────────────────
  /// [playerIndex] must equal game.currentPlayerIndex.
  /// [tokenId] is the token's id (0-3) within that player.
  static LudoGameModel moveToken(
      LudoGameModel game, int playerIndex, int tokenId) {
    final dice = game.diceValue;
    if (dice == null || !game.diceRolled) return game;

    // Safety: only the current player can move.
    if (playerIndex != game.currentPlayerIndex) return game;

    var players  = _copyPlayers(game.players);
    var rankings = List<String>.from(game.rankings);
    final pi     = playerIndex;
    final p      = players[pi];

    final tIdx = p.tokens.indexWhere((t) => t.id == tokenId);
    if (tIdx == -1) return game;

    var token           = p.tokens[tIdx];
    int scoreGain       = dice; // base score = dice face value
    bool capturedSomone = false;

    // Validate this token is actually movable.
    final movable = _movableTokens(p, dice, game.players);
    if (!movable.contains(tokenId)) return game;

    // ── Token in base ──────────────────────────────────────────────────────
    if (token.isInBase) {
      // Must be a 6 to exit (already validated by movableTokens, but guard here too)
      final startSq = colorStartSquare[p.color]!;
      token = token.copyWith(trackPos: startSq, totalRolled: dice);

      // Capture any lone opponent on the start square (not safe for opponents)
      // Start squares ARE safe for their own color but not for opponents.
      final captureResult =
          _checkCapture(players, pi, startSq, token, scoreGain);
      players         = captureResult.$1;
      scoreGain       = captureResult.$2;
      capturedSomone  = captureResult.$3;
    }

    // ── Token in home column ───────────────────────────────────────────────
    else if (token.isInHomeCol) {
      final newPos = token.trackPos + dice;
      if (newPos > _homeColFinal) return game; // overshoot → invalid

      if (newPos == _homeColFinal) {
        token = token.copyWith(
            isHome: true, trackPos: newPos, totalRolled: token.totalRolled + dice);
        scoreGain += 25; // bonus for reaching home
      } else {
        token = token.copyWith(
            trackPos: newPos, totalRolled: token.totalRolled + dice);
      }
    }

    // ── Token on main track ────────────────────────────────────────────────
    else {
      final homeEntry = colorHomeEntry[p.color]!;
      final dist      = _distOnTrack(token.trackPos, homeEntry);

      if (dice > dist) {
        // Enters home column
        final overshoot = dice - dist - 1; // 0-indexed steps into home col
        final homePos   = _homeColEntry + overshoot;
        if (homePos > _homeColFinal) return game; // overshoots home col

        if (homePos == _homeColFinal) {
          token = token.copyWith(
              isHome: true, trackPos: homePos, totalRolled: token.totalRolled + dice);
          scoreGain += 25;
        } else {
          token = token.copyWith(
              trackPos: homePos, totalRolled: token.totalRolled + dice);
        }
      } else if (dice == dist) {
        // Lands exactly on home entry → first step into home col
        token = token.copyWith(
            trackPos: _homeColEntry, totalRolled: token.totalRolled + dice);
      } else {
        // Normal move on main track
        final newPos = (token.trackPos + dice) % 52;
        token = token.copyWith(
            trackPos: newPos, totalRolled: token.totalRolled + dice);

        if (!safeSquares.contains(newPos)) {
          final captureResult =
              _checkCapture(players, pi, newPos, token, scoreGain);
          players        = captureResult.$1;
          scoreGain      = captureResult.$2;
          capturedSomone = captureResult.$3;
        }
      }
    }

    // Write token back
    final newTokens = List<LudoToken>.from(p.tokens);
    newTokens[tIdx] = token;
    players[pi]     = p.copyWith(tokens: newTokens, score: p.score + scoreGain);

    // ── Check if this player finished all tokens ───────────────────────────
    if (players[pi].allHome && !rankings.contains(players[pi].uid)) {
      rankings.add(players[pi].uid);

      final stillActive =
          players.where((pl) => !rankings.contains(pl.uid)).toList();

      if (stillActive.length <= 1) {
        if (stillActive.isNotEmpty) rankings.add(stillActive.first.uid);
        final rest = players
            .where((pl) => !rankings.contains(pl.uid))
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));
        for (final pl in rest) rankings.add(pl.uid);

        return game.copyWith(
          players:  players,
          rankings: rankings,
          status:   LudoGameStatus.finished,
        );
      }
    }

    // ── Extra turn on 6 or capture ─────────────────────────────────────────
    if (dice == 6 || capturedSomone) {
      return game.copyWith(
        players:          players,
        rankings:         rankings,
        diceRolled:       false,
        clearDiceValue:   true,
        extraTurn:        true,
        consecutiveSixes: dice == 6 ? game.consecutiveSixes + 1 : 0,
        turnTimeLeft:     10,
      );
    }

    return _advanceTurn(game.copyWith(players: players, rankings: rankings));
  }

  // ── Skip turn (timer expired) ──────────────────────────────────────────────
  static LudoGameModel skipTurn(LudoGameModel game) =>
      _advanceTurn(game.copyWith(turnTimeLeft: 10));

  // ── Rank by score (when global timer runs out) ─────────────────────────────
  static List<String> rankByScore(LudoGameModel game) {
    final remaining = game.players
        .where((p) => !game.rankings.contains(p.uid))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return [...game.rankings, ...remaining.map((p) => p.uid)];
  }

  // ── Public helper: returns movable token IDs for the current player ─────────
  static List<int> movableTokenIds(LudoGameModel game) {
    if (!game.diceRolled || game.diceValue == null) return [];
    final p = game.currentPlayer;
    return _movableTokens(p, game.diceValue!, game.players);
  }

  // ─────────────────────────── Private helpers ────────────────────────────────

  static LudoGameModel _advanceTurn(LudoGameModel game) {
    var nextIdx = (game.currentPlayerIndex + 1) % game.players.length;
    int tries   = 0;
    while (game.rankings.contains(game.players[nextIdx].uid) &&
        tries < game.players.length) {
      nextIdx = (nextIdx + 1) % game.players.length;
      tries++;
    }
    return game.copyWith(
      currentPlayerIndex: nextIdx,
      diceRolled:         false,
      clearDiceValue:     true,
      extraTurn:          false,
      consecutiveSixes:   0,
      turnTimeLeft:       10,
    );
  }

  static List<LudoPlayer> _copyPlayers(List<LudoPlayer> players) =>
      players
          .map((p) => p.copyWith(tokens: List<LudoToken>.from(p.tokens)))
          .toList();

  /// Returns token IDs that are legally movable for [p] given [dice].
  static List<int> _movableTokens(
      LudoPlayer p, int dice, List<LudoPlayer> allPlayers) {
    final ids = <int>[];

    for (final t in p.tokens) {
      if (t.isHome) continue;

      // ── In base: only a 6 can release a token ───────────────────────────
      if (t.isInBase) {
        if (dice <= 6) ids.add(t.id);
        continue;
      }

      // ── In home column: must not overshoot ──────────────────────────────
      if (t.isInHomeCol) {
        if (t.trackPos + dice <= _homeColFinal) ids.add(t.id);
        continue;
      }

      // ── On main track ────────────────────────────────────────────────────
      final homeEntry = colorHomeEntry[p.color]!;
      final dist      = _distOnTrack(t.trackPos, homeEntry);

      if (dice > dist) {
        // Token will enter home column — check it won't overshoot there
        final homePos = _homeColEntry + (dice - dist - 1);
        if (homePos <= _homeColFinal) ids.add(t.id);
        continue;
      }

      if (dice == dist) {
        ids.add(t.id);
        continue;
      }

      // Normal move — check destination is not blocked by 2+ opponent tokens
      final destTrack = (t.trackPos + dice) % 52;
      bool blocked    = false;

      for (final opp in allPlayers) {
        if (opp.uid == p.uid) continue;
        final onDest = opp.tokens
            .where((ot) => ot.isOnTrack && ot.trackPos == destTrack)
            .length;
        if (onDest >= 2) {
          blocked = true;
          break;
        }
      }

      if (!blocked) ids.add(t.id);
    }
    return ids;
  }

  /// Capture opponent tokens at [square].
  /// Returns (updatedPlayers, newScoreGain, didCapture).
  static (List<LudoPlayer>, int, bool) _checkCapture(
    List<LudoPlayer> players,
    int              pi,
    int              square,
    LudoToken        movingToken,
    int              scoreGain,
  ) {
    bool captured = false;

    for (int oi = 0; oi < players.length; oi++) {
      if (oi == pi) continue;
      final opp       = players[oi];
      final oppTokens = List<LudoToken>.from(opp.tokens);

      final onSquare = oppTokens
          .where((ot) => ot.isOnTrack && ot.trackPos == square)
          .toList();

      // Two or more opponent tokens = block; can't capture
      if (onSquare.length >= 2) continue;

      for (final ot in onSquare) {
        final idx     = oppTokens.indexWhere((x) => x.id == ot.id);
        final penalty = ot.totalRolled;
        oppTokens[idx] = ot.copyWith(trackPos: -1, totalRolled: 0);
        players[oi]    = opp.copyWith(
          tokens: oppTokens,
          score:  (opp.score - penalty).clamp(-9999, 9999),
        );
        scoreGain += 15;
        captured   = true;
      }
    }

    return (players, scoreGain, captured);
  }

  /// Clockwise distance from [from] to [to] on 52-square track.
  static int _distOnTrack(int from, int to) {
    if (to >= from) return to - from;
    return 52 - from + to;
  }
}