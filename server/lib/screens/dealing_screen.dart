import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:loteria_shared/loteria_shared.dart';

import '../services/game_repository.dart';
import '../widgets/stage_background.dart';
import '../widgets/winning_pattern_badge.dart';

const String _cardsSpriteAsset = 'assets/loteria_assets/cards-sprite.png';

/// `game_state == dealing` (spec.md section 3): "The stage shows how many
/// players got their tabla already and how many are in the game in total:
/// 'Dealing tabla %d of %d'. It can show a quick animation of each card
/// being handed out." The actual per-player writes (and their pacing) are
/// `AdminEngine`'s job (`server/lib/services/admin_engine.dart`); this
/// screen only reflects `players/<uid>/tabla_id` presence as it changes,
/// spawning one flying-tabla animation -- the player's *real* dealt tabla,
/// via the shared `Tabla` class -- per new arrival.
class DealingScreen extends StatefulWidget {
  const DealingScreen({super.key, required this.gameRepository});

  final GameRepository gameRepository;

  @override
  State<DealingScreen> createState() => _DealingScreenState();
}

class _DealingScreenState extends State<DealingScreen> {
  StreamSubscription<List<String>>? _sub;
  int? _gameId;
  int _dealtCount = 0;
  int _total = 0;
  int _nextFlyingId = 0;
  final Map<int, Tabla> _flying = {};
  WinningPattern? _winningPattern;

  // The first snapshot this listener ever sees becomes the baseline --
  // whatever's already dealt at mount time (a reload mid-round, most
  // commonly) shouldn't replay a burst of flying-tabla animations for
  // players who were dealt before this screen even opened. Only arrivals
  // seen *after* that baseline spawn one. Mirrors `DrawingScreen`'s
  // `_baselineDrawCount`, same reasoning.
  Set<String> _knownUids = {};
  bool _haveBaseline = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final gameId = await widget.gameRepository.fetchGameId();
    final progress = await widget.gameRepository.fetchDealingProgress();
    final winningPattern = await widget.gameRepository.fetchWinningPattern();
    if (!mounted) return;
    setState(() {
      _gameId = gameId;
      _total = progress.total;
      _winningPattern = winningPattern;
    });
    _sub = widget.gameRepository.watchDealtPlayerUids().listen(_onDealtUids);
  }

  void _onDealtUids(List<String> uids) {
    if (!mounted) return;
    final current = uids.where((uid) => uid.isNotEmpty).toSet();
    final newArrivals = _haveBaseline
        ? current.difference(_knownUids)
        : const <String>{};
    _haveBaseline = true;
    final gameId = _gameId;
    setState(() {
      _dealtCount = current.length;
      _knownUids = current;
      if (gameId != null) {
        for (final uid in newArrivals) {
          final id = _nextFlyingId++;
          // `Tabla.gameId` stays a String (shared cross-app contract,
          // combined with a player's UID -- always a string -- either way),
          // even though `game_id` itself is stored as a number now.
          _flying[id] = Tabla(gameId: gameId.toString(), tablaId: uid);
        }
      }
    });
  }

  void _removeFlying(int id) {
    if (!mounted) return;
    setState(() => _flying.remove(id));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StageBackground(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenSize = constraints.biggest;
          return Stack(
            children: [
              // One per tabla dealt so far, flying from center off the
              // edge of the screen -- rendered behind the labels below.
              for (final entry in _flying.entries)
                _FlyingTabla(
                  key: ValueKey(entry.key),
                  tabla: entry.value,
                  screenSize: screenSize,
                  onDone: () => _removeFlying(entry.key),
                ),
              Center(
                child: _DealingLabels(dealt: _dealtCount, total: _total),
              ),
              if (_winningPattern != null)
                Positioned(
                  top: 32,
                  right: 32,
                  child: WinningPatternBadge(pattern: _winningPattern!),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DealingLabels extends StatelessWidget {
  const _DealingLabels({required this.dealt, required this.total});

  final int dealt;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Dealing tablas...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 32,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Keyed by the dealt count so each increment rebuilds (and
        // re-animates) this subtree from scratch -- a quick "pop" per
        // tabla handed out (spec.md: "a quick animation of each card
        // being handed out"), on top of the flying-tabla animation behind
        // it.
        TweenAnimationBuilder<double>(
          key: ValueKey(dealt),
          tween: Tween(begin: 0.7, end: 1),
          duration: const Duration(milliseconds: 250),
          curve: Curves.elasticOut,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '$dealt of $total',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 96,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // implementation-plan.md v2 TODO: once every tabla is out, tell the
        // room the wait is over -- `total > 0` guards the brief moment
        // before `progress.total` has loaded, where both counts are still
        // zero and would otherwise falsely read as "done".
        if (total > 0 && dealt >= total) ...[
          const SizedBox(height: 24),
          const _ThrobbingLabel('Ready to play'),
        ],
      ],
    );
  }
}

/// A gently pulsing label -- same throb as [_ClaimCue] in
/// `drawing_screen.dart`, reused here rather than duplicated inline.
class _ThrobbingLabel extends StatefulWidget {
  const _ThrobbingLabel(this.text);

  final String text;

  @override
  State<_ThrobbingLabel> createState() => _ThrobbingLabelState();
}

class _ThrobbingLabelState extends State<_ThrobbingLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.94,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(scale: _scale.value, child: child);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.amber.shade600,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16)],
        ),
        child: Text(
          widget.text,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// A single player's real dealt tabla, flown once from the center of the
/// stage out past a random edge of the screen and gone -- as if tossed out
/// to whichever player it was just dealt to. Self-contained: plays once on
/// mount and reports back via [onDone] so the parent can drop it (it has
/// nothing left to show once off-screen).
class _FlyingTabla extends StatefulWidget {
  const _FlyingTabla({
    super.key,
    required this.tabla,
    required this.screenSize,
    required this.onDone,
  });

  final Tabla tabla;
  final Size screenSize;
  final VoidCallback onDone;

  @override
  State<_FlyingTabla> createState() => _FlyingTablaState();
}

class _FlyingTablaState extends State<_FlyingTabla>
    with SingleTickerProviderStateMixin {
  static const _tablaSize = 100.0;
  // Cards are portrait (250x375 in the sprite sheet), so the 4x4 grid
  // `_MiniTabla` renders is that same 2:3 ratio overall, not square --
  // needed here to center the flying tabla correctly (see [_MiniTabla]).
  static const _tablaHeight = _tablaSize * 375 / 250;

  late final AnimationController _controller;
  late final Animation<Offset> _offset;
  late final Animation<double> _opacity;
  late final double _rotation;

  @override
  void initState() {
    super.initState();
    final random = Random();
    final size = widget.screenSize;
    final center = Offset(
      size.width / 2 - _tablaSize / 2,
      size.height / 2 - _tablaHeight / 2,
    );
    final exitPoint = _randomExitPoint(random, size);
    _rotation = (random.nextDouble() - 0.5) * 1.4;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
    _offset = Tween<Offset>(
      begin: center,
      end: exitPoint,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInCubic));
    // Fully visible for most of the flight, fading only near the very end
    // as it exits the screen.
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 30),
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
  }

  /// A point well beyond one of the four edges -- flying *off* the screen,
  /// not just to its boundary.
  static Offset _randomExitPoint(Random random, Size size) {
    const overshoot = _tablaSize * 2;
    switch (random.nextInt(4)) {
      case 0: // off the top
        return Offset(random.nextDouble() * size.width, -overshoot);
      case 1: // off the bottom
        return Offset(
          random.nextDouble() * size.width,
          size.height + overshoot,
        );
      case 2: // off the left
        return Offset(-overshoot, random.nextDouble() * size.height);
      default: // off the right
        return Offset(
          size.width + overshoot,
          random.nextDouble() * size.height,
        );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _offset.value.dx,
          top: _offset.value.dy,
          child: Opacity(
            opacity: _opacity.value,
            child: Transform.rotate(angle: _rotation, child: child),
          ),
        );
      },
      child: _MiniTabla(tabla: widget.tabla, size: _tablaSize),
    );
  }
}

/// A player's real 4x4 tabla, cropped live from `cards-sprite.png` (the
/// same technique the player app uses to show it full-size), shrunk down
/// for this flying decoration.
class _MiniTabla extends StatelessWidget {
  const _MiniTabla({required this.tabla, required this.size});

  final Tabla tabla;

  /// Width; height is derived from the card's own portrait ratio (see
  /// [_FlyingTablaState._tablaHeight]) -- a 4x4 grid of 250x375 cards
  /// isn't square, so a square box would squash every card.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 375 / 250,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        // Both this Column and each Row below need `stretch`: without it,
        // the cross axis is a loose constraint, and CustomPaint (inside
        // SpriteCrop) has no intrinsic size of its own to fill it with --
        // it silently collapses to zero-size in that axis instead of
        // painting anything.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(4, (row) {
          return Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(4, (col) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(0.5),
                    child: SpriteCrop(
                      assetPath: _cardsSpriteAsset,
                      sourceRect: tabla.cardAt(row, col).spriteRect,
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
