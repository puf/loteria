import 'package:flutter/material.dart';

import 'screens/auth_error_screen.dart';
import 'screens/not_authorized_screen.dart';
import 'screens/stage_router.dart';
import 'services/game_repository.dart';
import 'state/admin_auth_controller.dart';

class LoteriaStageApp extends StatelessWidget {
  const LoteriaStageApp({
    super.key,
    required this.controller,
    required this.gameRepository,
  });

  final AdminAuthController controller;
  final GameRepository gameRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Loteria Stage',
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
      home: AnimatedBuilder(
        animation: controller,
        builder: (context, _) =>
            _AuthGate(controller: controller, gameRepository: gameRepository),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({required this.controller, required this.gameRepository});

  final AdminAuthController controller;
  final GameRepository gameRepository;

  @override
  Widget build(BuildContext context) {
    switch (controller.status) {
      case AdminAuthStatus.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AdminAuthStatus.signInFailed:
        return AuthErrorScreen(message: controller.errorMessage!);
      case AdminAuthStatus.notAuthorized:
        return NotAuthorizedScreen(controller: controller);
      case AdminAuthStatus.authorized:
        return StageRouter(gameRepository: gameRepository);
    }
  }
}
