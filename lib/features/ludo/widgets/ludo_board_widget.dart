import 'package:flutter/material.dart';
import '../models/ludo_models.dart';

// ── The standard Ludo 52-square main track mapped to 15×15 grid ──────────────
// Each entry is [row, col] on the 15×15 grid (0-indexed)
const List<List<int>> kTrack = [
  // Red path — starts at [6,1], goes right then up
  [6,1],[6,2],[6,3],[6,4],[6,5],         // 0–4
  [5,6],[4,6],[3,6],[2,6],[1,6],[0,6],   // 5–10
  [0,7],                                  // 11
  [0,8],[1,8],[2,8],[3,8],[4,8],[5,8],   // 12–17
  [6,9],[6,10],[6,11],[6,12],[6,13],     // 18–22
  [6,14],                                 // 23
  [7,14],                                 // 24
  [8,14],                                 // 25
  [8,13],[8,12],[8,11],[8,10],[8,9],     // 26–30
  [9,8],[10,8],[11,8],[12,8],[13,8],[14,8], // 31–36
  [14,7],                                 // 37
  [14,6],                                 // 38
  [13,6],[12,6],[11,6],[10,6],[9,6],     // 39–43
  [8,5],[8,4],[8,3],[8,2],[8,1],         // 44–48
  [8,0],                                  // 49
  [7,0],                                  // 50
  [6,0],                                  // 51
];

// Home column cells per color [row, col] — steps 0..4 (100..104), final=105
const Map<LudoColor, List<List<int>>> kHomeCol = {
  LudoColor.red:    [[6,1],[6,2],[6,3],[6,4],[6,5],[6,6]],   // actually goes inward
  LudoColor.green:  [[1,8],[2,8],[3,8],[4,8],[5,8],[6,8]],
  LudoColor.yellow: [[8,8],[8,9],[8,10],[8,11],[8,12],[8,13]],
  LudoColor.blue:   [[8,6],[7,6],[8,6],[7,6],[8,6],[7,6]],   // placeholder, fix below
};

// Corrected home column paths
const Map<LudoColor, List<List<int>>> kHomeColFix = {
  LudoColor.red:    [[6,1],[6,2],[6,3],[6,4],[6,5],[6,6]],
  LudoColor.green:  [[1,8],[2,8],[3,8],[4,8],[5,8],[6,8]],
  LudoColor.yellow: [[8,8],[8,9],[8,10],[8,11],[8,12],[8,13]],
  LudoColor.blue:   [[8,7],[8,6],[7,6],[6,6],[5,6],[6,6]], // simplified
};

// Base slot positions for each color's 4 tokens (row, col)
const Map<LudoColor, List<List<int>>> kBaseSlots = {
  LudoColor.red:    [[1,1],[1,3],[3,1],[3,3]],
  LudoColor.green:  [[1,11],[1,13],[3,11],[3,13]],
  LudoColor.yellow: [[11,11],[11,13],[13,11],[13,13]],
  LudoColor.blue:   [[11,1],[11,3],[13,1],[13,3]],
};

// Safe squares on main track
const Set<int> kSafeSquares = {0, 8, 13, 21, 26, 34, 39, 47};

// Color start square index on main track
const Map<LudoColor, int> kColorStart = {
  LudoColor.red:    0,
  LudoColor.green:  13,
  LudoColor.yellow: 26,
  LudoColor.blue:   39,
};

// Home column inner cells [row,col] for trackPos 100–104, 105=centre
const Map<LudoColor, List<List<int>>> kHomePath = {
  LudoColor.red:    [[6,1],[6,2],[6,3],[6,4],[6,5],[6,6]],
  LudoColor.green:  [[1,8],[2,8],[3,8],[4,8],[5,8],[6,8]],
  LudoColor.yellow: [[8,13],[8,12],[8,11],[8,10],[8,9],[8,8]],
  LudoColor.blue:   [[13,6],[12,6],[11,6],[10,6],[9,6],[8,6]],
};

Color ludoTokenColor(LudoColor c) {
  switch (c) {
    case LudoColor.red:    return const Color(0xFFE53935);
    case LudoColor.green:  return const Color(0xFF2E7D32);
    case LudoColor.yellow: return const Color(0xFFF9A825);
    case LudoColor.blue:   return const Color(0xFF1565C0);
  }
}

class LudoBoardWidget extends StatelessWidget {
  final LudoGameModel game;
  final List<int>     movableTokenIds;
  final void Function(int tokenId, LudoColor color) onTokenTap;

  const LudoBoardWidget({
    super.key,
    required this.game,
    required this.movableTokenIds,
    required this.onTokenTap,
  });

  @override
  Widget build(BuildContext context) {
    final size  = MediaQuery.of(context).size;
    final board = (size.width < size.height ? size.width : size.height) - 16;
    final sq    = board / 15;

    return Container(
      width: board, height: board,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.5),
          blurRadius: 20, spreadRadius: 4,
        )],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(children: [
          // Static board
          CustomPaint(size: Size(board, board), painter: _BoardPainter(sq: sq)),
          // Tokens
          for (final player in game.players)
            for (final token in player.tokens)
              _TokenWidget(
                token:       token,
                player:      player,
                sq:          sq,
                isMovable:   movableTokenIds.contains(token.id) &&
                             game.currentPlayer.color == player.color,
                onTap:       () => onTokenTap(token.id, player.color),
              ),
        ]),
      ),
    );
  }
}

// ── Animated token widget ─────────────────────────────────────────────────────

class _TokenWidget extends StatefulWidget {
  final LudoToken   token;
  final LudoPlayer  player;
  final double      sq;
  final bool        isMovable;
  final VoidCallback onTap;

  const _TokenWidget({
    required this.token,
    required this.player,
    required this.sq,
    required this.isMovable,
    required this.onTap,
  });

  @override
  State<_TokenWidget> createState() => _TokenWidgetState();
}

class _TokenWidgetState extends State<_TokenWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  Offset _getPosition() {
    final sq  = widget.sq;
    final tok = widget.token;
    final col = widget.player.color;

    if (tok.isHome) return const Offset(-200, -200); // hide

    if (tok.isInBase) {
      final slot = kBaseSlots[col]![tok.id];
      return Offset(slot[1] * sq, slot[0] * sq);
    }

    if (tok.isInHomeCol) {
      final step = (tok.trackPos - 100).clamp(0, 5);
      final path = kHomePath[col]!;
      final cell = path[step];
      return Offset(cell[1] * sq, cell[0] * sq);
    }

    // Main track
    final pos = tok.trackPos.clamp(0, 51);
    final cell = kTrack[pos];
    return Offset(cell[1] * sq, cell[0] * sq);
  }

  @override
  Widget build(BuildContext context) {
    final pos   = _getPosition();
    final sq    = widget.sq;
    final color = ludoTokenColor(widget.player.color);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve:    Curves.easeInOut,
      left: pos.dx + sq * 0.1,
      top:  pos.dy + sq * 0.1,
      child: GestureDetector(
        onTap: widget.isMovable ? widget.onTap : null,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) {
            final scale = widget.isMovable ? 1.0 + _pulse.value * 0.18 : 1.0;
            return Transform.scale(scale: scale, child: child);
          },
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.elasticOut,
            // Key on trackPos so it re-triggers every time token moves
            key: ValueKey(widget.token.trackPos),
            builder: (_, val, child) => Transform.scale(scale: val, child: child),
            child: Container(
              width:  sq * 0.8,
              height: sq * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(
                  color: widget.isMovable ? Colors.white : Colors.white.withOpacity(0.45),
                  width: widget.isMovable ? 2.5 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.isMovable
                        ? color.withOpacity(0.8)
                        : Colors.black.withOpacity(0.35),
                    blurRadius: widget.isMovable ? 12 : 4,
                    spreadRadius: widget.isMovable ? 3 : 0,
                  ),
                ],
              ),
              child: Center(child: Text(
                '${widget.token.id + 1}',
                style: TextStyle(
                  color:      Colors.white,
                  fontSize:   sq * 0.28,
                  fontWeight: FontWeight.w800,
                  shadows: const [Shadow(color: Colors.black45, blurRadius: 2)],
                ),
              )),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Board painter ─────────────────────────────────────────────────────────────

class _BoardPainter extends CustomPainter {
  final double sq;
  const _BoardPainter({required this.sq});

  static const _red    = Color(0xFFE53935);
  static const _green  = Color(0xFF2E7D32);
  static const _yellow = Color(0xFFF9A825);
  static const _blue   = Color(0xFF1565C0);
  static const _safe   = Color(0xFFC8E6C9);

  @override
  void paint(Canvas canvas, Size size) {
    final fill   = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.grey.shade400
      ..strokeWidth = 0.6;

    // White background
    fill.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), fill);

    // ── Corner bases (6×6) ───────────────────────────────────────────────────
    _drawBase(canvas, fill, 0,  0,  _red,    'R');
    _drawBase(canvas, fill, 9,  0,  _green,  'G');
    _drawBase(canvas, fill, 9,  9,  _yellow, 'Y');
    _drawBase(canvas, fill, 0,  9,  _blue,   'B');

    // ── Track squares ────────────────────────────────────────────────────────
    for (int i = 0; i < kTrack.length; i++) {
      final r = kTrack[i][0];
      final c = kTrack[i][1];
      final rect = Rect.fromLTWH(c * sq, r * sq, sq, sq);

      // Color coding
      if (i == kColorStart[LudoColor.red])    fill.color = _red.withOpacity(0.5);
      else if (i == kColorStart[LudoColor.green])   fill.color = _green.withOpacity(0.5);
      else if (i == kColorStart[LudoColor.yellow])  fill.color = _yellow.withOpacity(0.5);
      else if (i == kColorStart[LudoColor.blue])    fill.color = _blue.withOpacity(0.5);
      else if (kSafeSquares.contains(i))            fill.color = _safe;
      else fill.color = Colors.white;

      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, stroke);

      // Star on safe squares (not start squares)
      if (kSafeSquares.contains(i) &&
          i != 0 && i != 13 && i != 26 && i != 39) {
        _drawStar(canvas,
            Offset(c * sq + sq / 2, r * sq + sq / 2),
            sq * 0.3, const Color(0xFF66BB6A));
      }
    }

    // ── Home columns (colored paths inward) ──────────────────────────────────
    _drawHomePath(canvas, fill, stroke, LudoColor.red,    _red);
    _drawHomePath(canvas, fill, stroke, LudoColor.green,  _green);
    _drawHomePath(canvas, fill, stroke, LudoColor.yellow, _yellow);
    _drawHomePath(canvas, fill, stroke, LudoColor.blue,   _blue);

    // ── Centre home triangle ─────────────────────────────────────────────────
    _drawCentre(canvas, fill);

    // ── Grid over whole board ─────────────────────────────────────────────────
    for (int i = 0; i <= 15; i++) {
      canvas.drawLine(
          Offset(i * sq, 0), Offset(i * sq, size.height), stroke);
      canvas.drawLine(
          Offset(0, i * sq), Offset(size.width, i * sq), stroke);
    }
  }

  void _drawBase(Canvas c, Paint p, int startCol, int startRow,
      Color color, String label) {
    // Outer fill
    p.color = color;
    c.drawRect(Rect.fromLTWH(
        startCol * sq, startRow * sq, 6 * sq, 6 * sq), p);

    // Inner white inset
    p.color = Colors.white;
    c.drawRect(Rect.fromLTWH(
        (startCol + 0.5) * sq, (startRow + 0.5) * sq,
        5 * sq, 5 * sq), p);

    // Inner colored circle area
    final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          (startCol + 1) * sq, (startRow + 1) * sq, 4 * sq, 4 * sq),
      Radius.circular(sq * 0.5),
    );
    p.color = color.withOpacity(0.18);
    c.drawRRect(rr, p);

    // Token slot circles
    final slots = kBaseSlots.entries
        .firstWhere((e) {
          final s = e.value.first;
          // Match by rough area
          return (s[1] >= startCol && s[1] < startCol + 6 &&
                  s[0] >= startRow && s[0] < startRow + 6);
        }, orElse: () => kBaseSlots.entries.first)
        .value;

    for (final slot in slots) {
      p.color = color.withOpacity(0.35);
      c.drawCircle(
        Offset((slot[1] + 0.5) * sq, (slot[0] + 0.5) * sq),
        sq * 0.38, p,
      );
      p.color = Colors.white.withOpacity(0.6);
      c.drawCircle(
        Offset((slot[1] + 0.5) * sq, (slot[0] + 0.5) * sq),
        sq * 0.28, p,
      );
    }
  }

  void _drawHomePath(Canvas c, Paint fill, Paint stroke,
      LudoColor color, Color col) {
    final path = kHomePath[color]!;
    for (int i = 0; i < path.length - 1; i++) {
      final cell = path[i];
      final rect = Rect.fromLTWH(cell[1] * sq, cell[0] * sq, sq, sq);
      fill.color = col.withOpacity(0.15 + i * 0.12);
      c.drawRect(rect, fill);
      c.drawRect(rect, stroke);
    }
  }

  void _drawCentre(Canvas c, Paint p) {
    final cx   = 7.5 * sq;
    final cy   = 7.5 * sq;
    final half = 1.5 * sq;

    final tris = [
      ([Offset(cx, cy), Offset(cx - half, cy - half), Offset(cx + half, cy - half)], _red),
      ([Offset(cx, cy), Offset(cx + half, cy - half), Offset(cx + half, cy + half)], _green),
      ([Offset(cx, cy), Offset(cx + half, cy + half), Offset(cx - half, cy + half)], _yellow),
      ([Offset(cx, cy), Offset(cx - half, cy + half), Offset(cx - half, cy - half)], _blue),
    ];

    for (final t in tris) {
      final path = Path()
        ..moveTo(t.$1[0].dx, t.$1[0].dy)
        ..lineTo(t.$1[1].dx, t.$1[1].dy)
        ..lineTo(t.$1[2].dx, t.$1[2].dy)
        ..close();
      p.color = t.$2;
      c.drawPath(path, p);
    }

    _drawStar(c, Offset(cx, cy), sq * 0.5, Colors.white);
  }

  void _drawStar(Canvas c, Offset centre, double r, Color color) {
    final p    = Paint()..color = color;
    final path = Path();
    const pi   = 3.14159265;

    for (int i = 0; i < 5; i++) {
      final outerAngle = (i * 72 - 90) * pi / 180;
      final innerAngle = ((i * 72 + 36) - 90) * pi / 180;
      final ox = centre.dx + r * _cos(outerAngle);
      final oy = centre.dy + r * _sin(outerAngle);
      final ix = centre.dx + r * 0.42 * _cos(innerAngle);
      final iy = centre.dy + r * 0.42 * _sin(innerAngle);
      if (i == 0) path.moveTo(ox, oy); else path.lineTo(ox, oy);
      path.lineTo(ix, iy);
    }
    path.close();
    c.drawPath(path, p);
  }

  static double _cos(double r) =>
      1 - r*r/2 + r*r*r*r/24 - r*r*r*r*r*r/720;

  static double _sin(double r) =>
      r - r*r*r/6 + r*r*r*r*r/120 - r*r*r*r*r*r*r/5040;

  @override
  bool shouldRepaint(_BoardPainter o) => o.sq != sq;
}