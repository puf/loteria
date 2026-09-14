import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/game_repository.dart';
import 'state/admin_auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final controller = AdminAuthController(AuthService(FirebaseAuth.instance));
  unawaited(controller.start());

  final gameRepository = GameRepository(FirebaseDatabase.instance);

  runApp(
    LoteriaStageApp(controller: controller, gameRepository: gameRepository),
  );
}
