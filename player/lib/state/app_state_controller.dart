// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:loteria_shared/loteria_shared.dart';

import '../services/auth_service.dart';
import '../services/game_repository.dart';
import '../services/presence_service.dart';
import 'app_screen.dart';

/// Combines auth + the Firebase listeners (`game_state`, `game`,
/// `players/<uid>`, `blocked_uids/<uid>`) into the single screen the player
/// app should currently show, and exposes the actions the player can take
/// (`claimLoteria`).
///
/// This is the player app's state-to-screen router. It intentionally uses
/// nothing beyond `ChangeNotifier` (no external state-management package).
/// Reconnect is handled implicitly, not as a distinct code path: a fresh
/// subscribe on any of the underlying streams re-emits the current value,
/// so a reload just re-derives [screen] from whatever's authoritative in
/// the database at that moment -- there's no separate "reconnecting" state.
class AppStateController extends ChangeNotifier {
  AppStateController({
    required AuthService authService,
    required PresenceService presenceService,
    required GameRepository gameRepository,
  }) : _authService = authService,
       _presenceService = presenceService,
       _gameRepository = gameRepository;

  final AuthService _authService;
  final PresenceService _presenceService;
  final GameRepository _gameRepository;

  String? _uid;
  GameState? _gameState;
  bool _gameStateLoaded = false;
  String? _claimingUid;
  String? _gameId;
  String? _tablaId;
  bool _blocked = false;
  WinningPattern? _winningPattern;

  StreamSubscription<GameState?>? _gameStateSub;
  StreamSubscription<Map<Object?, Object?>?>? _gameSub;
  StreamSubscription<String?>? _tablaSub;
  StreamSubscription<bool>? _blockedSub;

  String? get uid => _uid;
  GameState? get gameState => _gameState;
  String? get claimingUid => _claimingUid;
  String? get gameId => _gameId;
  String? get tablaId => _tablaId;
  bool get blocked => _blocked;
  WinningPattern? get winningPattern => _winningPattern;

  /// spec.md section 3: "While the player's ID is in claiming_uid, the
  /// player screen flashes white" -- unconditional on `game_state`, and
  /// additive to whatever [screen] is currently showing rather than a
  /// screen of its own (the board, beans, and button stay exactly as they
  /// otherwise would; only a flash gets layered on top).
  bool get isMyActiveClaim => _uid != null && _claimingUid == _uid;

  /// Signs the player in, writes lobby presence, and attaches the
  /// per-player/per-game listeners. Safe to call once at app start.
  Future<void> start() async {
    final user = await _authService.ensureSignedIn();
    _uid = user.uid;
    notifyListeners();

    await _presenceService.markPresent(user.uid);

    _gameStateSub = _gameRepository.watchGameState().listen((value) {
      _gameState = value;
      _gameStateLoaded = true;
      notifyListeners();
    });
    _gameSub = _gameRepository.watchGame().listen((value) {
      final claiming = value?['claiming_uid'];
      _claimingUid = claiming is String ? claiming : null;
      _gameId = value?['game_id']?.toString();
      _winningPattern = WinningPattern.fromRaw(value?['winning_pattern']);
      notifyListeners();
    });
    _tablaSub = _gameRepository.watchTablaId(user.uid).listen((value) {
      _tablaId = value;
      notifyListeners();
    });
    _blockedSub = _gameRepository.watchBlocked(user.uid).listen((value) {
      _blocked = value;
      notifyListeners();
    });
  }

  AppScreen get screen {
    final uid = _uid;
    if (uid == null || !_gameStateLoaded) return AppScreen.connecting;

    // A missing `game_state` value means there is no active game, which is
    // equivalent to `lobby` (spec.md section 4).
    final state = _gameState ?? GameState.lobby;

    // Every state past `lobby` needs a tabla (both IDs feed its seed -- see
    // Tabla), and the three Firebase listeners this depends on
    // (game_state, tabla_id, game_id) are independent subscriptions with no
    // ordering guarantee between them. That matters most on reconnect: a
    // fresh load can have `game_state` arrive as, say, `checking` before
    // this player's own `tabla_id`/`game_id` have. Guarding here once,
    // ahead of the switch, covers every such state instead of only
    // `dealing`/`drawing` -- without it, a reconnect landing mid-game could
    // hit a null tabla downstream.
    if (state != GameState.lobby && (_tablaId == null || _gameId == null)) {
      return AppScreen.dealingWaitingForTabla;
    }

    switch (state) {
      case GameState.lobby:
        return AppScreen.lobby;
      case GameState.dealing:
        return AppScreen.dealingTablaReceived;
      case GameState.drawing:
        return AppScreen.drawing;
      case GameState.paused:
        // Same board as `drawing` (spec.md: beans are pure client-side UI
        // independent of state); the Loteria button's own `gameState ==
        // GameState.drawing` check (see app.dart) is what actually
        // disables it while paused -- spec.md's button rule is literally
        // "game_state == drawing", and paused isn't that.
        return AppScreen.drawing;
      case GameState.claiming:
        return AppScreen.claiming;
      case GameState.checking:
        return AppScreen.checking;
      case GameState.cheater:
        return AppScreen.cheater;
      case GameState.winner:
      case GameState.celebrate:
        return AppScreen.winnerOrCelebrate;
    }
  }

  /// Claims Loteria for the current player. The write may be legitimately
  /// rejected by the database rules (e.g. someone else claimed first); per
  /// implementation-plan.md that must not surface as an error, so any
  /// failure here is swallowed -- the UI just stays on `drawing` until
  /// `game_state` changes on its own.
  Future<void> claimLoteria() async {
    final currentUid = _uid;
    if (currentUid == null) return;
    try {
      await _gameRepository.writeClaim(currentUid);
    } catch (_) {
      // Rejected claim: no-op by design.
    }
  }

  @override
  void dispose() {
    _gameStateSub?.cancel();
    _gameSub?.cancel();
    _tablaSub?.cancel();
    _blockedSub?.cancel();
    super.dispose();
  }
}
