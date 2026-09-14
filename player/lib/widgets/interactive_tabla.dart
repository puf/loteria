import 'package:flutter/material.dart';
import 'package:loteria_shared/loteria_shared.dart';

import 'card_sprite_image.dart';
import 'tabla_geometry.dart';

const double beanDisplaySize = 50;

const List<double> _grayscaleMatrix = [
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// Drag payload marker for a bean coming from the pile (a brand new bean),
/// as opposed to an existing placed bean being moved (whose payload is its
/// [BeanPlacement.id], an int) -- lets the single whole-board [DragTarget]
/// tell "place a new bean" apart from "move this bean" by payload type.
class NewBeanToken {
  const NewBeanToken();
}

/// A bean placed at an exact position (intrinsic grid-space px, same
/// coordinate system as tabla_geometry.dart) rather than merely "in cell N"
/// -- drag-and-drop drops land wherever the user actually drops them.
class BeanPlacement {
  const BeanPlacement({required this.id, required this.position});

  final int id;
  final Offset position;
}

/// The tabla shown across every post-dealing screen (see
/// `GameBoardScreen`): interactive while `game_state == drawing` (tap a
/// cell to drop a bean where tapped, drag a bean from the pile below to
/// drop it anywhere on the board, drag a placed bean to move it, or tap
/// (without dragging) a placed bean to remove it), read-only otherwise.
/// This widget always wires up real gesture handling -- it doesn't know
/// about interactivity itself; `GameBoardScreen` gates it by no-op'ing its
/// own callback bodies when not interactive, so the board still displays
/// (and beans stay visible) either way.
///
/// Uses the shared geometry from tabla_geometry.dart and a single
/// FittedBox-around-a-fixed-size-Stack, so gesture/drop coordinates and
/// card positions always agree regardless of how much the board ends up
/// scaled to fit the screen.
class InteractiveTabla extends StatefulWidget {
  const InteractiveTabla({
    super.key,
    required this.tabla,
    required this.beans,
    required this.onTapAt,
    required this.onDropAt,
    required this.onMoveBean,
    required this.onRemoveBean,
    this.grayedOut = false,
  });

  final Tabla tabla;
  final List<BeanPlacement> beans;
  final ValueChanged<Offset> onTapAt;
  final ValueChanged<Offset> onDropAt;
  final void Function(int id, Offset newPosition) onMoveBean;
  final ValueChanged<int> onRemoveBean;

  /// Desaturates and dims the tabla (spec.md section 3: "grayed out tabla,
  /// with a 'Waiting to start' label over it", shown while `dealing`).
  /// Gestures are left wired up either way -- callers gate interactivity by
  /// passing no-op callbacks when it shouldn't apply, not via this flag.
  final bool grayedOut;

  @override
  State<InteractiveTabla> createState() => _InteractiveTablaState();
}

class _InteractiveTablaState extends State<InteractiveTabla> {
  final _boardKey = GlobalKey();

  Offset _toLocal(Offset globalOffset) {
    final box = _boardKey.currentContext!.findRenderObject() as RenderBox;
    return box.globalToLocal(globalOffset);
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        key: _boardKey,
        width: tablaGridWidth,
        height: tablaGridHeight,
        child: DragTarget<Object>(
          onAcceptWithDetails: (details) {
            final local = _toLocal(details.offset);
            if (details.data is int) {
              widget.onMoveBean(details.data as int, local);
            } else {
              widget.onDropAt(local);
            }
          },
          builder: (context, candidateData, rejectedData) {
            Widget stack = Stack(
              clipBehavior: Clip.none,
              children: [
                for (var row = 0; row < 4; row++)
                  for (var col = 0; col < 4; col++)
                    Positioned.fromRect(
                      rect: tablaCellRect(row, col),
                      child: CardSpriteImage(
                        card: widget.tabla.cardAt(row, col),
                      ),
                    ),
                for (final bean in widget.beans)
                  Positioned(
                    left: bean.position.dx - beanDisplaySize / 2,
                    top: bean.position.dy - beanDisplaySize / 2,
                    child: Draggable<int>(
                      data: bean.id,
                      dragAnchorStrategy: pointerDragAnchorStrategy,
                      feedback: const BeanImage(size: beanDisplaySize),
                      childWhenDragging: const Opacity(
                        opacity: 0.3,
                        child: BeanImage(size: beanDisplaySize),
                      ),
                      child: GestureDetector(
                        onTap: () => widget.onRemoveBean(bean.id),
                        child: const BeanImage(size: beanDisplaySize),
                      ),
                    ),
                  ),
              ],
            );

            if (widget.grayedOut) {
              stack = ColorFiltered(
                colorFilter: const ColorFilter.matrix(_grayscaleMatrix),
                child: Opacity(opacity: 0.55, child: stack),
              );
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => widget.onTapAt(details.localPosition),
              child: stack,
            );
          },
        ),
      ),
    );
  }
}
