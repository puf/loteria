import 'package:flutter_test/flutter_test.dart';
import 'package:loteria_shared/loteria_shared.dart';

void main() {
  test('same gameId+tabla_id always produces the same 16 cards', () {
    final a = Tabla(gameId: '1', tablaId: '42');
    final b = Tabla(gameId: '1', tablaId: '42');
    expect(a.cards.map((c) => c.slug), b.cards.map((c) => c.slug));
  });

  test('a different gameId changes the tabla for the same tabla_id', () {
    final a = Tabla(gameId: '1', tablaId: '42');
    final b = Tabla(gameId: '2', tablaId: '42');
    expect(a.cards.map((c) => c.slug), isNot(b.cards.map((c) => c.slug)));
  });

  test('a different tabla_id changes the tabla for the same gameId', () {
    final a = Tabla(gameId: '1', tablaId: '42');
    final b = Tabla(gameId: '1', tablaId: '43');
    expect(a.cards.map((c) => c.slug), isNot(b.cards.map((c) => c.slug)));
  });

  test('a tabla has 16 distinct cards', () {
    final tabla = Tabla(gameId: '7', tablaId: '3');
    expect(tabla.cards.length, 16);
    expect(tabla.cards.map((c) => c.slug).toSet().length, 16);
  });

  test('cardAt(row, col) matches the row-major cards list', () {
    final tabla = Tabla(gameId: '7', tablaId: '3');
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 4; col++) {
        expect(tabla.cardAt(row, col), tabla.cards[row * 4 + col]);
      }
    }
  });
}
