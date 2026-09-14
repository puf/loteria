import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/game_repository.dart';
import 'services/presence_service.dart';
import 'state/app_state_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final controller = AppStateController(
    authService: AuthService(FirebaseAuth.instance),
    presenceService: PresenceService(FirebaseDatabase.instance),
    gameRepository: GameRepository(FirebaseDatabase.instance),
  );
  unawaited(controller.start());

  runApp(LoteriaPlayerApp(controller: controller));
}
