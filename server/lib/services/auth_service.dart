import 'package:firebase_auth/firebase_auth.dart';

/// Host auth for the stage/admin app: Firebase anonymous auth for now
/// (matching the player app's approach), gated by a server-assigned
/// `isAdmin` custom claim (spec.md section 2C).
///
/// This app never grants that claim itself -- it only reads it. Granting it
/// is the Admin SDK bootstrap script's job (tools/grant_admin_claim.mjs),
/// which accepts the anonymous UID directly (`--uid=<uid>`) since an
/// anonymous account has no email to target by.
///
/// Checking the claim here is purely a UI convenience ("still good to hide
/// this UI" -- spec.md section 2C); the real enforcement is the database's
/// security rules checking `auth.token.isAdmin`.
class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  Future<User> ensureSignedIn() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing;
    final credential = await _auth.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      throw StateError('Anonymous sign-in returned a null user.');
    }
    return user;
  }

  /// Whether the current user's ID token carries `isAdmin: true`. A custom
  /// claim only shows up in a freshly issued token, so pass
  /// [forceRefresh]: true right after the bootstrap script has been run for
  /// this user.
  Future<bool> checkIsAdmin({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final result = await user.getIdTokenResult(forceRefresh);
    return result.claims?['isAdmin'] == true;
  }
}
