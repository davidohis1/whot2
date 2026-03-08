import 'dart:math';
import '../models/whot_models.dart';

class WhotEngine {
  static final _rng = Random.secure();

  // ── Setup ─────────────────────────────────────────────────────────────────

  static WhotGameModel createGame({
    required String gameId,
    required List<({String uid, String name})> players,
  }) {
    assert(players.length == 4);

    var deck = buildWhotDeck()..shuffle(_rng);

    const handSize = 5;
    final hands = List.generate(4, (_) => <WhotCard>[]);
    for (int i = 0; i < handSize * 4; i++) {
      hands[i % 4].add(deck.removeAt(0));
    }

    // Flip starter — avoid Whot 20 as first card
    WhotCard starter;
    do { starter = deck.removeAt(0); } while (starter.isWhot && deck.isNotEmpty);
    if (starter.isWhot) deck.add(starter); // edge case

    final gamePlayers = List.generate(4, (i) => WhotPlayer(
      uid:      players[i].uid,
      name:     players[i].name,
      hand:     hands[i],
      position: i,
    ));

    return WhotGameModel(
      gameId:             gameId,
      players:            gamePlayers,
      market:             deck,
      pile:               [starter],
      currentPlayerIndex: 0,
      status:             WhotGameStatus.active,
      rankings:           [],
      createdAt:          DateTime.now(),
      startedAt:          DateTime.now(),
      timeLeftSeconds:    420,
    );
  }

  // ── Play card ─────────────────────────────────────────────────────────────

  /// [calledShape] must be provided if card played is a Whot 20.
  static WhotGameModel playCard(
    WhotGameModel game,
    WhotCard card, {
    WhotShape? calledShape,
  }) {
    assert(card.canPlayOn(game.topCard, calledShape: game.calledShape));

    var players = _copyPlayers(game.players);
    var market  = List<WhotCard>.from(game.market);
    var pile    = List<WhotCard>.from(game.pile);
    var rankings = List<String>.from(game.rankings);

    // Remove card from current player's hand
    final pi = game.currentPlayerIndex;
    final hand = List<WhotCard>.from(players[pi].hand)..remove(card);
    players[pi] = players[pi].copyWith(hand: hand);

    pile.add(card);

    // Check win condition
    if (hand.isEmpty) {
      rankings.add(players[pi].uid);
      // Remove player from rotation — game continues with remaining
      players = List.from(players);

      // All finished?
      final active = players.where((p) => !rankings.contains(p.uid)).toList();
      if (active.length <= 1) {
        if (active.isNotEmpty) rankings.add(active.first.uid);
        return game.copyWith(
          players: players,
          pile:    pile,
          market:  market,
          status:  WhotGameStatus.finished,
          rankings: rankings,
        );
      }
    }

    // Determine action effects
    WhotActionPending newPending = WhotActionPending.none;
    int               pendingCount = 0;
    bool              skipExtra   = false;

    // Stack pick-two / pick-three
    if (card.number == 2) {
      if (game.pending == WhotActionPending.pickTwo) {
        newPending   = WhotActionPending.pickTwo;
        pendingCount = game.pendingCount + 2;
      } else {
        newPending   = WhotActionPending.pickTwo;
        pendingCount = 2;
      }
    } else if (card.number == 5) {
      newPending   = WhotActionPending.pickThree;
      pendingCount = (game.pending == WhotActionPending.pickThree
          ? game.pendingCount : 0) + 3;
    } else if (card.number == 8) {
      newPending = WhotActionPending.suspension;
    } else if (card.number == 14) {
      // General Market — everyone else draws 1
      final cIdx = game.currentPlayerIndex;
      for (int i = 0; i < players.length; i++) {
        if (i == cIdx) continue;
        if (rankings.contains(players[i].uid)) continue;
        if (market.isEmpty) _reshuffleMarket(pile, market);
        if (market.isNotEmpty) {
          final draw = market.removeAt(0);
          players[i] = players[i].copyWith(hand: [...players[i].hand, draw]);
        }
      }
    } else if (card.number == 1) {
      // Hold On — same player goes again
      return game.copyWith(
        players:         players,
        pile:            pile,
        market:          market,
        calledShape:     calledShape,
        clearCalledShape: calledShape == null,
        pending:         WhotActionPending.none,
        pendingCount:    0,
        rankings:        rankings,
      );
    }

    // Advance turn
    var nextIdx = _nextActivePlayer(game.currentPlayerIndex, players, rankings);

    // Handle suspension (skip next)
    if (newPending == WhotActionPending.suspension) {
      nextIdx = _nextActivePlayer(nextIdx, players, rankings);
      newPending   = WhotActionPending.none;
    }

    return game.copyWith(
      players:          players,
      pile:             pile,
      market:           market,
      currentPlayerIndex: nextIdx,
      calledShape:      card.isWhot ? calledShape : null,
      clearCalledShape: !card.isWhot,
      pending:          newPending,
      pendingCount:     pendingCount,
      rankings:         rankings,
    );
  }

  // ── Draw from market ──────────────────────────────────────────────────────

  static WhotGameModel drawFromMarket(WhotGameModel game, {int count = 1}) {
    var players = _copyPlayers(game.players);
    var market  = List<WhotCard>.from(game.market);
    var pile    = List<WhotCard>.from(game.pile);
    final pi    = game.currentPlayerIndex;

    final drawn = <WhotCard>[];
    for (int i = 0; i < count; i++) {
      if (market.isEmpty) _reshuffleMarket(pile, market);
      if (market.isEmpty) break;
      drawn.add(market.removeAt(0));
    }

    players[pi] = players[pi].copyWith(hand: [...players[pi].hand, ...drawn]);

    // After drawing because of penalty → advance turn
    final nextIdx = _nextActivePlayer(pi, players, List.from(game.rankings));

    return game.copyWith(
      players:          players,
      market:           market,
      pile:             pile,
      currentPlayerIndex: nextIdx,
      pending:          WhotActionPending.none,
      pendingCount:     0,
    );
  }

  // ── Auto-skip (turn timer expired) ───────────────────────────────────────

  static WhotGameModel skipTurn(WhotGameModel game) {
    final pi       = game.currentPlayerIndex;
    var   players  = _copyPlayers(game.players);
    var   market   = List<WhotCard>.from(game.market);
    var   pile     = List<WhotCard>.from(game.pile);
    final rankings = List<String>.from(game.rankings);

    // If there's a pending pick penalty, force-draw those cards first
    if (game.pending != WhotActionPending.none && game.pendingCount > 0) {
      final drawn = <WhotCard>[];
      for (int i = 0; i < game.pendingCount; i++) {
        if (market.isEmpty) _reshuffleMarket(pile, market);
        if (market.isEmpty) break;
        drawn.add(market.removeAt(0));
      }
      players[pi] =
          players[pi].copyWith(hand: [...players[pi].hand, ...drawn]);
    }

    final nextIdx = _nextActivePlayer(pi, players, rankings);

    return game.copyWith(
      players:            players,
      market:             market,
      pile:               pile,
      currentPlayerIndex: nextIdx,
      pending:            WhotActionPending.none,
      pendingCount:       0,
      turnTimeLeft:       10,
    );
  }

  // ── Timer end ─────────────────────────────────────────────────────────────

  /// Determine rankings by card count (fewest = best).
  /// Rank all remaining players by card count when global timer ends.
  static List<String> rankByCardCount(WhotGameModel game) {
    final remaining = game.players
        .where((p) => !game.rankings.contains(p.uid))
        .toList()
      ..sort((a, b) => a.hand.length.compareTo(b.hand.length));
    return [...game.rankings, ...remaining.map((p) => p.uid)];
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static int _nextActivePlayer(
      int current, List<WhotPlayer> players, List<String> rankings) {
    int next = (current + 1) % players.length;
    int tries = 0;
    while (rankings.contains(players[next].uid) && tries < 4) {
      next = (next + 1) % players.length;
      tries++;
    }
    return next;
  }

  static List<WhotPlayer> _copyPlayers(List<WhotPlayer> players) =>
      players.map((p) => p.copyWith(hand: List<WhotCard>.from(p.hand))).toList();

  static void _reshuffleMarket(List<WhotCard> pile, List<WhotCard> market) {
    if (pile.length <= 1) return;
    final top = pile.removeLast();
    market.addAll(pile..shuffle(Random.secure()));
    pile.clear();
    pile.add(top);
  }

  // ── Playable cards ────────────────────────────────────────────────────────

  static List<WhotCard> playableCards(WhotGameModel game, List<WhotCard> hand) {
    // If pending pick, can only defend with same pick card
    if (game.pending == WhotActionPending.pickTwo) {
      return hand.where((c) => c.number == 2).toList();
    }
    if (game.pending == WhotActionPending.pickThree) {
      return hand.where((c) => c.number == 5).toList();
    }
    return hand.where((c) => c.canPlayOn(game.topCard, calledShape: game.calledShape)).toList();
  }
}