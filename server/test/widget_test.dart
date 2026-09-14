import 'package:flutter_test/flutter_test.dart';
import 'package:loteria_server/state/admin_auth_controller.dart';

void main() {
  test('AdminAuthStatus has the four expected gate states', () {
    expect(AdminAuthStatus.values, [
      AdminAuthStatus.loading,
      AdminAuthStatus.signInFailed,
      AdminAuthStatus.notAuthorized,
      AdminAuthStatus.authorized,
    ]);
  });
}
