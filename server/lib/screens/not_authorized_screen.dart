import 'package:flutter/material.dart';

import '../state/admin_auth_controller.dart';

/// Signed in anonymously, but the ID token doesn't carry `isAdmin: true`
/// yet.
///
/// spec.md section 2C: this UI gate is just a courtesy -- "all data
/// manipulation will actually be checked in the security rules of the
/// database, so this is just an extra check whether to even show the UI or
/// not". The actual grant happens out-of-band via tools/grant_admin_claim.mjs,
/// targeting this UID (anonymous accounts have no email to target by).
class NotAuthorizedScreen extends StatelessWidget {
  const NotAuthorizedScreen({super.key, required this.controller});

  final AdminAuthController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'This browser does not have admin access.',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 8),
            SelectableText(
              'UID: ${controller.uid}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ask an existing admin to run tools/grant_admin_claim.mjs --uid=<the UID above>',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: controller.recheckAdminAccess,
              child: const Text('Recheck admin access'),
            ),
          ],
        ),
      ),
    );
  }
}
