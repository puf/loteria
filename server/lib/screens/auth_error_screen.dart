import 'package:flutter/material.dart';

/// Anonymous sign-in itself failed (rare -- e.g. anonymous auth not enabled
/// for this Firebase project).
class AuthErrorScreen extends StatelessWidget {
  const AuthErrorScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
