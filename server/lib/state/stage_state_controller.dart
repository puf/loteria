import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:loteria_shared/loteria_shared.dart';

import '../services/game_repository.dart';
import 'stage_screen.dart';

/// Projects the authoritative `game_state` in Firebase onto a [StageScreen].
/// The stage display is a live projection of that state, not a separate
/// source of truth (implementation-plan.md) -- this controller never writes
/// `game_state` itself, only reads it.
class StageStateController extends ChangeNotifier {
  StageStateController(this._gameRepository);

  final GameRepository _gameRepository;

  GameState? _gameState;
  bool _loaded = false;
  StreamSubscription<GameState?>? _sub;

  GameState? get gameState => _gameState;

  /// Attaches the `game_state` listener. Safe to call once; repeat calls
  /// are no-ops.
  void start() {
    _sub ??= _gameRepository.watchGameState().listen((value) {
      _gameState = value;
      _loaded = true;
      notifyListeners();
    });
  }

  StageScreen get screen {
    if (!_loaded) return StageScreen.connecting;

    // A missing `game_state` value means there is no active game, which is
    // equivalent to `lobby` (spec.md section 4).
    final state = _gameState ?? GameState.lobby;

    switch (state) {
      case GameState.lobby:
        return StageScreen.lobby;
      case GameState.dealing:
        return StageScreen.dealing;
      case GameState.drawing:
        return StageScreen.drawing;
      case GameState.paused:
        return StageScreen.paused;
      case GameState.claiming:
        return StageScreen.claiming;
      case GameState.checking:
        return StageScreen.checking;
      case GameState.cheater:
        return StageScreen.cheater;
      case GameState.winner:
        return StageScreen.winner;
      case GameState.celebrate:
        return StageScreen.celebrate;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
