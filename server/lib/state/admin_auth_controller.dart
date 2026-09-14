import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

enum AdminAuthStatus {
  /// Auth state hasn't resolved yet (initial load, or a claim recheck).
  loading,

  /// Anonymous sign-in itself failed (rare -- e.g. anonymous auth not
  /// enabled for this Firebase project).
  signInFailed,

  /// Signed in, but the ID token doesn't carry `isAdmin: true`.
  notAuthorized,

  /// Signed in and `isAdmin: true` -- may act as the authoritative admin.
  authorized,
}

/// Drives the auth gate: signs in anonymously, then checks whether the
/// resulting user carries the `isAdmin` custom claim. Nothing beyond
/// `ChangeNotifier` (no external state-management package), matching the
/// player app's approach.
class AdminAuthController extends ChangeNotifier {
  AdminAuthController(this._authService);

  final AuthService _authService;

  AdminAuthStatus _status = AdminAuthStatus.loading;
  String? _errorMessage;

  AdminAuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get uid => _authService.currentUser?.uid;

  /// Signs in and checks the claim. Safe to call once at app start.
  Future<void> start() async {
    try {
      await _authService.ensureSignedIn();
    } catch (e) {
      _errorMessage = 'Sign-in failed: $e';
      _status = AdminAuthStatus.signInFailed;
      notifyListeners();
      return;
    }
    await _refreshClaim();
  }

  Future<void> _refreshClaim({bool forceRefresh = false}) async {
    final isAdmin = await _authService.checkIsAdmin(forceRefresh: forceRefresh);
    _status = isAdmin
        ? AdminAuthStatus.authorized
        : AdminAuthStatus.notAuthorized;
    notifyListeners();
  }

  /// Re-checks the claim with a forced token refresh -- use this right
  /// after running the bootstrap script for this UID, since a custom claim
  /// only appears in a freshly issued ID token.
  Future<void> recheckAdminAccess() => _refreshClaim(forceRefresh: true);
}
