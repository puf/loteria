import 'package:flutter_test/flutter_test.dart';
import 'package:loteria_shared/loteria_shared.dart';

void main() {
  test('GameState.fromRaw parses all nine known values', () {
    for (final state in GameState.values) {
      expect(GameState.fromRaw(state.name), state);
    }
  });

  test('GameState.fromRaw returns null for unknown or missing values', () {
    expect(GameState.fromRaw('not_a_state'), isNull);
    expect(GameState.fromRaw(null), isNull);
  });

  test('loteriaDeck has exactly 54 cards with unique slugs', () {
    expect(loteriaDeck.length, 54);
    expect(loteriaDeck.map((c) => c.slug).toSet().length, 54);
  });

  test('each card has a positive-length audio clip', () {
    for (final card in loteriaDeck) {
      expect(card.audioStart, greaterThanOrEqualTo(Duration.zero));
      expect(card.audioDuration, greaterThan(Duration.zero));
    }
  });

  test('audio clips are back-to-back and non-overlapping in cards.mp3', () {
    final byStart = [...loteriaDeck]
      ..sort((a, b) => a.audioStart.compareTo(b.audioStart));
    for (var i = 0; i < byStart.length - 1; i++) {
      final end = byStart[i].audioStart + byStart[i].audioDuration;
      expect(
        end,
        lessThanOrEqualTo(byStart[i + 1].audioStart),
        reason:
            '${byStart[i].slug} overlaps the next clip (${byStart[i + 1].slug})',
      );
    }
  });

  test('WinningPattern.fromRaw parses all five known values', () {
    for (final pattern in WinningPattern.values) {
      expect(WinningPattern.fromRaw(pattern.raw), pattern);
    }
  });

  test('WinningPattern.fromRaw returns null for unknown or missing values', () {
    expect(WinningPattern.fromRaw('not_a_pattern'), isNull);
    expect(WinningPattern.fromRaw(null), isNull);
  });

  test(
    'every WinningPattern has exactly four example cells inside the grid',
    () {
      for (final pattern in WinningPattern.values) {
        final cells = pattern.exampleCells;
        expect(cells.length, 4);
        for (final (row, col) in cells) {
          expect(row, inInclusiveRange(0, 3));
          expect(col, inInclusiveRange(0, 3));
        }
      }
    },
  );

  group('WinningPattern.isSatisfiedBy', () {
    test('four in a row (horizontal) accepts any complete row', () {
      const pattern = WinningPattern.fourInARowHorizontal;
      expect(pattern.isSatisfiedBy({0, 1, 2, 3}), isTrue);
      expect(pattern.isSatisfiedBy({4, 5, 6, 7}), isTrue);
      expect(pattern.isSatisfiedBy({12, 13, 14, 15}), isTrue);
      expect(pattern.isSatisfiedBy({0, 1, 2, 4}), isFalse);
      // A complete column shouldn't satisfy a horizontal requirement.
      expect(pattern.isSatisfiedBy({0, 4, 8, 12}), isFalse);
    });

    test('four in a row (vertical) accepts any complete column', () {
      const pattern = WinningPattern.fourInARowVertical;
      expect(pattern.isSatisfiedBy({0, 4, 8, 12}), isTrue);
      expect(pattern.isSatisfiedBy({3, 7, 11, 15}), isTrue);
      expect(pattern.isSatisfiedBy({0, 1, 2, 3}), isFalse);
    });

    test('four in a row (diagonal) accepts either diagonal only', () {
      const pattern = WinningPattern.fourInARowDiagonal;
      expect(pattern.isSatisfiedBy({0, 5, 10, 15}), isTrue);
      expect(pattern.isSatisfiedBy({3, 6, 9, 12}), isTrue);
      expect(pattern.isSatisfiedBy({0, 1, 2, 3}), isFalse);
    });

    test('four corners requires exactly the four corners', () {
      const pattern = WinningPattern.fourCorners;
      expect(pattern.isSatisfiedBy({0, 3, 12, 15}), isTrue);
      expect(pattern.isSatisfiedBy({0, 3, 12, 14}), isFalse);
    });

    test('el pozo accepts any of the nine possible 2x2 blocks', () {
      const pattern = WinningPattern.elPozo;
      expect(pattern.isSatisfiedBy({0, 1, 4, 5}), isTrue); // top-left block
      expect(pattern.isSatisfiedBy({10, 11, 14, 15}), isTrue); // bottom-right
      expect(pattern.isSatisfiedBy({1, 2, 5, 6}), isTrue); // an inner block
      // Diagonal quartet, not a contiguous 2x2 block.
      expect(pattern.isSatisfiedBy({0, 5, 10, 15}), isFalse);
    });

    test('an empty or unrelated set never satisfies any pattern', () {
      for (final pattern in WinningPattern.values) {
        expect(pattern.isSatisfiedBy(<int>{}), isFalse);
        expect(pattern.isSatisfiedBy({1, 8, 13}), isFalse);
      }
    });
  });

  group('WinningPattern.satisfyingCellSets', () {
    test('empty when the pattern is not satisfied', () {
      expect(
        WinningPattern.fourCorners.satisfyingCellSets({0, 3, 12, 14}),
        isEmpty,
      );
    });

    test('a single completed row returns exactly that row', () {
      final sets = WinningPattern.fourInARowHorizontal.satisfyingCellSets({
        4,
        5,
        6,
        7,
      });
      expect(sets, [
        {4, 5, 6, 7},
      ]);
    });

    test('multiple completed rows are all returned', () {
      final sets = WinningPattern.fourInARowHorizontal.satisfyingCellSets({
        0,
        1,
        2,
        3,
        12,
        13,
        14,
        15,
      });
      expect(sets, unorderedEquals([
        {0, 1, 2, 3},
        {12, 13, 14, 15},
      ]));
    });

    test('multiple overlapping el pozo blocks are all returned', () {
      // A full top row of 2x2 blocks: three overlapping blocks all complete.
      final sets = WinningPattern.elPozo.satisfyingCellSets({
        0, 1, 2, 3, 4, 5, 6, 7,
      });
      expect(sets, unorderedEquals([
        {0, 1, 4, 5},
        {1, 2, 5, 6},
        {2, 3, 6, 7},
      ]));
    });
  });
}
