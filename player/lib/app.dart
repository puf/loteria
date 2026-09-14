import 'package:flutter/material.dart';
import 'package:loteria_shared/loteria_shared.dart';

import 'screens/game_board_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/placeholder_screen.dart';
import 'state/app_screen.dart';
import 'state/app_state_controller.dart';
import 'widgets/claim_flash_overlay.dart';

class LoteriaPlayerApp extends StatelessWidget {
  const LoteriaPlayerApp({super.key, required this.controller});

  final AppStateController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Loteria',
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
      home: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => _ScreenRouter(controller: controller),
      ),
    );
  }
}

/// Maps [AppStateController.screen] to the widget for that screen, then
/// layers a flash overlay on top when [AppStateController.isMyActiveClaim]
/// -- the flash is additive, not a replacement screen, so whatever's
/// underneath (the board, beans, the Loteria button) stays exactly as it
/// otherwise would.
///
/// `dealingTablaReceived` through `winnerOrCelebrate` all share the one
/// persistent `GameBoardScreen` layout (button + tabla + bean pile always
/// present, per-state only its enabled/interactive/label/grayed-out
/// parameters differ), so the UI never shifts across those states.
class _ScreenRouter extends StatelessWidget {
  const _ScreenRouter({required this.controller});

  final AppStateController controller;

  Tabla _currentTabla() {
    return Tabla(gameId: controller.gameId!, tablaId: controller.tablaId!);
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildScreen();
    return controller.isMyActiveClaim
        ? ClaimFlashOverlay(child: content)
        : content;
  }

  Widget _buildScreen() {
    switch (controller.screen) {
      case AppScreen.connecting:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AppScreen.lobby:
        return LobbyScreen(uid: controller.uid!);
      case AppScreen.dealingWaitingForTabla:
        return const PlaceholderScreen(label: 'Waiting for tabla...');
      case AppScreen.dealingTablaReceived:
        return GameBoardScreen(
          tabla: _currentTabla(),
          interactive: false,
          buttonEnabled: false,
          winningPattern: controller.winningPattern,
          grayedOut: true,
          label: 'Waiting to start...',
          onClaim: controller.claimLoteria,
          uid: controller.uid!,
        );
      case AppScreen.drawing:
        return GameBoardScreen(
          tabla: _currentTabla(),
          interactive: true,
          // AppScreen.drawing also covers `paused` (same board); the
          // button itself still needs the real game_state to be `drawing`
          // specifically, per spec.md's literal button rule.
          buttonEnabled:
              controller.gameState == GameState.drawing &&
              !controller.blocked &&
              controller.claimingUid == null,
          winningPattern: controller.winningPattern,
          onClaim: controller.claimLoteria,
          uid: controller.uid!,
        );
      case AppScreen.claiming:
        return GameBoardScreen(
          tabla: _currentTabla(),
          interactive: false,
          buttonEnabled: false,
          winningPattern: controller.winningPattern,
          onClaim: controller.claimLoteria,
          uid: controller.uid!,
        );
      case AppScreen.checking:
        return GameBoardScreen(
          tabla: _currentTabla(),
          interactive: false,
          buttonEnabled: false,
          winningPattern: controller.winningPattern,
          label: 'Checking claim...',
          onClaim: controller.claimLoteria,
          uid: controller.uid!,
        );
      case AppScreen.cheater:
        return GameBoardScreen(
          tabla: _currentTabla(),
          interactive: false,
          buttonEnabled: false,
          winningPattern: controller.winningPattern,
          onClaim: controller.claimLoteria,
          uid: controller.uid!,
        );
      case AppScreen.winnerOrCelebrate:
        final youWon = controller.claimingUid == controller.uid;
        return GameBoardScreen(
          tabla: _currentTabla(),
          interactive: false,
          buttonEnabled: false,
          winningPattern: controller.winningPattern,
          label: youWon
              ? '¡Lotería! You won!'
              : "Great game, but you didn't win.",
          onClaim: controller.claimLoteria,
          uid: controller.uid!,
        );
    }
  }
}
