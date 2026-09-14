import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:loteria_shared/loteria_shared.dart';

import '../services/draw_order.dart';
import '../services/game_repository.dart';
import '../widgets/stage_background.dart';

const String _cardsSpriteAsset = 'assets/loteria_assets/cards-sprite.png';

/// `game_state == celebrate` (spec.md: "shows that there was a winner, and
/// animations of fireworks and Loteria cards"; implementation-plan.md:
/// "winner result on the stage... a high-energy end-of-round moment before
/// reset"). Stays up until the host fires `next_game`
/// (`celebrate -> next_game -> lobby`), so the confetti loops for as long
/// as this screen is shown, not just a one-shot burst.
class CelebrateScreen extends StatefulWidget {
  const CelebrateScreen({super.key, required this.gameRepository});

  final GameRepository gameRepository;

  @override
  State<CelebrateScreen> createState() => _CelebrateScreenState();
}

class _CelebrateScreenState extends State<CelebrateScreen> {
  Tabla? _winningTabla;
  String? _winningUid;
  // implementation-plan.md v2 TODO: highlight the actual winning line/
  // shape(s) on the winner's tabla -- every distinct completed instance,
  // not just one, per the TODO's own "if there are multiple ... put beans
  // on all of them".
  List<Set<int>> _winningCellSets = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gameId = await widget.gameRepository.fetchGameId();
    final uid = await widget.gameRepository.fetchClaimingUid();
    if (gameId == null || uid == null) return;
    final tablaId = await widget.gameRepository.fetchTablaId(uid);
    final winningPattern = await widget.gameRepository.fetchWinningPattern();
    final drawCount = await widget.gameRepository.fetchDrawCount();
    if (tablaId == null || !mounted) return;

    final tabla = Tabla(gameId: gameId.toString(), tablaId: tablaId);
    var winningCellSets = const <Set<int>>[];
    if (winningPattern != null) {
      // Same "which cells are drawn" derivation `ClaimEngine` used to
      // validate this exact claim in the first place -- draw_count is
      // frozen by the time `celebrate` is reached, so this reconstructs
      // the identical drawn set.
      final order = drawOrderFor(gameId);
      final drawnSlugs = order.take(drawCount).map((c) => c.slug).toSet();
      final drawnCellIndices = <int>{
        for (var i = 0; i < tabla.cards.length; i++)
          if (drawnSlugs.contains(tabla.cards[i].slug)) i,
      };
      winningCellSets = winningPattern.satisfyingCellSets(drawnCellIndices);
    }

    setState(() {
      _winningTabla = tabla;
      _winningUid = uid;
      _winningCellSets = winningCellSets;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabla = _winningTabla;
    return StageBackground(
      child: Stack(
        children: [
          const Positioned.fill(child: _Confetti()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '¡LOTERÍA!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 80,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 16)],
                  ),
                ),
                if (_winningUid != null) ...[
                  const SizedBox(height: 16),
                  _WinnerUidBadge(uid: _winningUid!),
                ],
                const SizedBox(height: 32),
                if (tabla != null)
                  _WinningTablaGrid(
                    tabla: tabla,
                    winningCellSets: _winningCellSets,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The winning player's UID, shown the same way [WinnerScreen] shows it --
/// this screen replaces that one, so the identity shouldn't disappear once
/// the celebration starts.
class _WinnerUidBadge extends StatelessWidget {
  const _WinnerUidBadge({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade600,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16)],
      ),
      child: Text(
        uid,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// The winning tabla, shown in full (spec.md: "animations of ... Loteria
/// cards") -- reuses the same live sprite-cropping technique as every
/// other card display in this app.
class _WinningTablaGrid extends StatelessWidget {
  const _WinningTablaGrid({required this.tabla, required this.winningCellSets});

  final Tabla tabla;

  /// Every distinct completed line/shape on this tabla (see
  /// `WinningPattern.satisfyingCellSets`) -- a cell is highlighted if it
  /// belongs to *any* of them, so overlapping shapes (e.g. two El Pozo
  /// blocks sharing an edge) light up correctly as a combined region.
  final List<Set<int>> winningCellSets;

  // Cards are portrait (250x375 in the sprite sheet, the same 2:3 ratio
  // `card_sprite_image.dart` uses in the player app) -- a 4x4 grid of them
  // is that same ratio overall, not square. Sizing the outer box to match
  // means the equal Row/Column subdivision below gives each cell the
  // correct proportions too, instead of squashing every card into a
  // square slot.
  static const _width = 360.0;
  static const _height = _width * 375 / 250;

  bool _isWinningCell(int row, int col) {
    final index = row * 4 + col;
    return winningCellSets.any((cells) => cells.contains(index));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _width,
      height: _height,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(4, (row) {
          return Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(4, (col) {
                final isWinning = _isWinningCell(row, col);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        SpriteCrop(
                          assetPath: _cardsSpriteAsset,
                          sourceRect: tabla.cardAt(row, col).spriteRect,
                        ),
                        if (isWinning) const Positioned.fill(child: _WinningCellOverlay()),
                      ],
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}

/// A static border (kept thin so the card art underneath stays legible --
/// an earlier pulsing/glowing version obscured the card itself, per user
/// feedback) plus a scaling, pulsing bean marking a winning cell.
class _WinningCellOverlay extends StatefulWidget {
  const _WinningCellOverlay();

  @override
  State<_WinningCellOverlay> createState() => _WinningCellOverlayState();
}

class _WinningCellOverlayState extends State<_WinningCellOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.amberAccent, width: 3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_controller.value);
              return Transform.scale(scale: 0.9 + t * 0.3, child: child);
            },
            child: const BeanImage(size: 36),
          ),
        ),
      ],
    );
  }
}

/// A looping field of falling, tumbling confetti pieces -- purely
/// decorative, behind the winner announcement. Each piece's horizontal
/// position, fall speed, size, color, and rotation are fixed once at
/// mount; only the fall progress animates, wrapping back to the top when a
/// piece exits the bottom so the celebration keeps going for as long as
/// this screen is shown.
class _Confetti extends StatefulWidget {
  const _Confetti();

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  static const _pieceCount = 40;
  static const _colors = [
    Color(0xFFFFD54F),
    Color(0xFFE07A29),
    Color(0xFF9A2B1E),
    Color(0xFFFFFFFF),
    Color(0xFF4CAF50),
  ];

  late final AnimationController _controller;
  late final List<_ConfettiPiece> _pieces;

  @override
  void initState() {
    super.initState();
    final random = Random();
    _pieces = List.generate(_pieceCount, (i) {
      return _ConfettiPiece(
        left: random.nextDouble(),
        fallDuration: 2.5 + random.nextDouble() * 3.5,
        startDelay: random.nextDouble(),
        size: 8 + random.nextDouble() * 10,
        color: _colors[random.nextInt(_colors.length)],
        spin: (random.nextDouble() - 0.5) * 8,
      );
    });
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // A slowly-advancing clock in seconds, shared by every piece --
            // each piece derives its own fall position from this plus its
            // own duration/delay/phase, so they don't all reset in sync.
            final elapsed = DateTime.now().millisecondsSinceEpoch / 1000.0;
            return Stack(
              children: [
                for (final piece in _pieces) _buildPiece(piece, size, elapsed),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPiece(_ConfettiPiece piece, Size size, double elapsed) {
    final t = ((elapsed / piece.fallDuration) + piece.startDelay) % 1.0;
    final top = t * (size.height + 40) - 20;
    final angle = elapsed * piece.spin;
    return Positioned(
      left: piece.left * size.width,
      top: top,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: piece.size,
          height: piece.size * 0.6,
          color: piece.color,
        ),
      ),
    );
  }
}

class _ConfettiPiece {
  _ConfettiPiece({
    required this.left,
    required this.fallDuration,
    required this.startDelay,
    required this.size,
    required this.color,
    required this.spin,
  });

  final double left;
  final double fallDuration;
  final double startDelay;
  final double size;
  final Color color;
  final double spin;
}
