import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

/// Local-only, player-only state (spec.md: "Local player-only state (not in
/// database)"). NOT shared with host/admin -- purely a UI convenience so
/// bean placements survive a reload within the same game.
///
/// Keyed by `game_id`, cleared whenever a new game starts (implementation-
/// plan.md: "Bean placement is only persisted in local storage. This
/// storage is cleared when the game starts"). Stores exact positions
/// (intrinsic tabla-grid-space px, see tabla_geometry.dart), not just which
/// cell -- beans can be dropped anywhere on a cell, not only centered.
class BeanStorage {
  static const _beansKey = 'bean_placements';
  static const _gameIdKey = 'bean_placements_game_id';

  /// Loads bean positions for [gameId]. If [gameId] differs from the last
  /// game seen, stale placements are cleared first and an empty list is
  /// returned.
  Future<List<Offset>> load(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_gameIdKey) != gameId) {
      await prefs.remove(_beansKey);
      await prefs.setString(_gameIdKey, gameId);
      return [];
    }
    final stored = prefs.getStringList(_beansKey) ?? const [];
    return stored.map(_decode).whereType<Offset>().toList();
  }

  Future<void> save(String gameId, List<Offset> positions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_gameIdKey, gameId);
    await prefs.setStringList(_beansKey, positions.map(_encode).toList());
  }

  static String _encode(Offset position) => '${position.dx},${position.dy}';

  static Offset? _decode(String stored) {
    final parts = stored.split(',');
    if (parts.length != 2) return null;
    final dx = double.tryParse(parts[0]);
    final dy = double.tryParse(parts[1]);
    if (dx == null || dy == null) return null;
    return Offset(dx, dy);
  }
}
