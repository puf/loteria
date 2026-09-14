import 'package:flutter/material.dart';
import 'package:loteria_shared/loteria_shared.dart';

import '../services/bean_storage.dart';
import '../widgets/interactive_tabla.dart';
import '../widgets/tabla_geometry.dart';
import '../widgets/winning_pattern_badge.dart';

/// The single persistent layout for every state where the player has a
/// tabla to look at: `dealing` (once dealt), `drawing`, `claiming`,
/// `checking`, `cheater`, `winner`/`celebrate`.
///
/// The button and bean pile are always present -- only their enabled state,
/// the tabla's interactivity, whether it's grayed out, and an optional
/// overlay label change per game state. Nothing about the layout itself
/// appears or disappears between these states, so the UI never shifts.
///
/// Beans are always loaded from local storage (so the board looks the same
/// whether or not the player can currently edit it); they're only actually
/// mutable while [interactive] is true.
class GameBoardScreen extends StatefulWidget {
  const GameBoardScreen({
    super.key,
    required this.tabla,
    required this.interactive,
    required this.buttonEnabled,
    required this.onClaim,
    required this.uid,
    this.winningPattern,
    this.grayedOut = false,
    this.label,
  });

  final Tabla tabla;

  /// implementation-plan.md v2 TODO: shown persistently during play (not
  /// just on the lobby screen) so the host can identify a claimant on
  /// sight without asking.
  final String uid;

  /// Whether tapping/dragging on the tabla or pile actually places, moves,
  /// or removes beans. True only during `drawing`.
  final bool interactive;

  final bool buttonEnabled;
  final VoidCallback onClaim;

  /// What shape the player needs on their tabla to win this round -- null
  /// only in the brief window before `game/winning_pattern` has loaded.
  final WinningPattern? winningPattern;

  final bool grayedOut;
  final String? label;

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  final _beanStorage = BeanStorage();
  List<BeanPlacement> _beans = [];
  int _nextBeanId = 0;

  @override
  void initState() {
    super.initState();
    _loadBeans();
  }

  @override
  void didUpdateWidget(covariant GameBoardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabla.gameId != widget.tabla.gameId) {
      _loadBeans();
    }
  }

  void _loadBeans() {
    _beanStorage.load(widget.tabla.gameId).then((positions) {
      if (!mounted) return;
      setState(() {
        _beans = [
          for (final position in positions)
            BeanPlacement(id: _nextBeanId++, position: position),
        ];
      });
    });
  }

  void _persist() {
    _beanStorage.save(widget.tabla.gameId, [
      for (final b in _beans) b.position,
    ]);
  }

  void _handleTapAt(Offset position) {
    if (!widget.interactive) return;

    final cellIndex = tablaCellIndexAt(position);
    if (cellIndex == null) return; // tapped the gap between cells

    final cellAlreadyHasBean = _beans.any(
      (b) => tablaCellIndexAt(b.position) == cellIndex,
    );
    if (cellAlreadyHasBean) return; // tap elsewhere in an occupied cell: no-op

    _addBean(position);
  }

  void _handleDropAt(Offset position) {
    if (!widget.interactive) return;
    _addBean(position);
  }

  void _addBean(Offset position) {
    setState(() {
      _beans = [
        ..._beans,
        BeanPlacement(id: _nextBeanId++, position: position),
      ];
    });
    _persist();
  }

  void _removeBean(int id) {
    if (!widget.interactive) return;
    setState(() {
      _beans = _beans.where((b) => b.id != id).toList();
    });
    _persist();
  }

  void _moveBean(int id, Offset newPosition) {
    if (!widget.interactive) return;
    setState(() {
      _beans = [
        for (final b in _beans)
          if (b.id == id) BeanPlacement(id: id, position: newPosition) else b,
      ];
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: widget.buttonEnabled ? widget.onClaim : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('¡LOTERÍA!'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.winningPattern != null)
                    WinningPatternBadge(pattern: widget.winningPattern!)
                  else
                    const SizedBox.shrink(),
                  _UidBadge(uid: widget.uid),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: InteractiveTabla(
                      tabla: widget.tabla,
                      beans: _beans,
                      grayedOut: widget.grayedOut,
                      onTapAt: _handleTapAt,
                      onDropAt: _handleDropAt,
                      onMoveBean: _moveBean,
                      onRemoveBean: _removeBean,
                    ),
                  ),
                  if (widget.label != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface
                            .withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.label!,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                ],
              ),
            ),
            _BeanPile(enabled: widget.interactive),
          ],
        ),
      ),
    );
  }
}

/// The player's own UID, shown persistently alongside the winning-pattern
/// badge -- same pill styling as the board's own overlay label (`surface`
/// at 85% alpha) for visual consistency within this screen.
class _UidBadge extends StatelessWidget {
  const _UidBadge({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(uid, style: const TextStyle(fontSize: 12)),
    );
  }
}

/// The source of beans to drag onto the board. Beans are unlimited (spec.md:
/// "They have an infinite number of beans"), so this is just a decorative
/// row of identical draggable bean icons, not a depleting supply. Dimmed
/// and inert outside `drawing` -- present so the layout doesn't shift, but
/// dragging from it wouldn't do anything (`GameBoardScreen` only applies
/// drops while `interactive`), so it shouldn't invite the attempt.
class _BeanPile extends StatelessWidget {
  const _BeanPile({required this.enabled});

  final bool enabled;

  static const _pileBeanSize = 56.0;
  static const _pileCount = 6;

  @override
  Widget build(BuildContext context) {
    final pile = Container(
      height: 72,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      // FittedBox so the pile shrinks to fit on narrow screens instead of
      // silently clipping the last bean (Flutter clips Row overflow within
      // its own canvas rather than growing the page, so there'd be no
      // scrollbar to reveal it either).
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _pileCount; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Draggable<NewBeanToken>(
                data: const NewBeanToken(),
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: const BeanImage(size: _pileBeanSize),
                childWhenDragging: const Opacity(
                  opacity: 0.3,
                  child: BeanImage(size: _pileBeanSize),
                ),
                child: const BeanImage(size: _pileBeanSize),
              ),
            ],
          ],
        ),
      ),
    );

    if (enabled) return pile;
    return IgnorePointer(child: Opacity(opacity: 0.4, child: pile));
  }
}
