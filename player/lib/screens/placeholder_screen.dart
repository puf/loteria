import 'package:flutter/material.dart';

/// A simple centered-text screen. Used for `dealingWaitingForTabla`
/// ("Waiting for tabla...") -- the one player-app state with no board to
/// show yet, so there's nothing for a persistent layout to apply to.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(label, style: const TextStyle(fontSize: 20))),
    );
  }
}
