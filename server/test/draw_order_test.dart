import 'package:flutter_test/flutter_test.dart';
import 'package:loteria_shared/loteria_shared.dart';
import 'package:loteria_server/services/draw_order.dart';

void main() {
  test('drawOrderFor is a full-deck permutation with no duplicates', () {
    final order = drawOrderFor(1);
    expect(order.length, 54);
    expect(order.map((c) => c.slug).toSet().length, 54);
    expect(
      order.map((c) => c.slug).toSet(),
      loteriaDeck.map((c) => c.slug).toSet(),
    );
  });

  test('the same gameId always produces the same draw order', () {
    final a = drawOrderFor(1);
    final b = drawOrderFor(1);
    expect(a.map((c) => c.slug), b.map((c) => c.slug));
  });

  test('a different gameId produces a different draw order', () {
    final a = drawOrderFor(1);
    final b = drawOrderFor(2);
    expect(a.map((c) => c.slug), isNot(b.map((c) => c.slug)));
  });
}
