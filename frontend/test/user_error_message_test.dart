import 'package:flutter_test/flutter_test.dart';
import 'package:safearms_frontend/models/user_model.dart';
import 'package:safearms_frontend/providers/user_provider.dart';
import 'package:safearms_frontend/services/api_client.dart';
import 'package:safearms_frontend/services/user_service.dart';
import 'package:safearms_frontend/utils/error_message_utils.dart';

void main() {
  test('userFacingErrorMessage removes exception and API wrappers', () {
    expect(
      userFacingErrorMessage(
        ApiException(
          statusCode: 409,
          message: 'Email address is already used by another user.',
        ),
      ),
      'Email address is already used by another user.',
    );

    expect(
      userFacingErrorMessage(
        Exception(
          'Error updating user: ApiException(409): Username is already used by another user. [url: http://localhost]',
        ),
      ),
      'Username is already used by another user.',
    );
  });

  test('createUser stores friendly duplicate email message', () async {
    final provider = UserProvider(
      userService: _FailingUserService(
        'Email address is already used by another user.',
      ),
    );

    final success = await provider.createUser(
      username: 'duplicate',
      password: 'Password@123',
      fullName: 'Duplicate User',
      email: 'duplicate@example.com',
      phoneNumber: '0780000000',
      role: 'admin',
    );

    expect(success, isFalse);
    expect(
      provider.errorMessage,
      'Email address is already used by another user.',
    );
  });

  test('updateUser stores friendly duplicate username message', () async {
    final provider = UserProvider(
      userService: _FailingUserService(
        'Username is already used by another user.',
      ),
    );

    final success = await provider.updateUser(
      userId: 'USR-001',
      username: 'duplicate',
    );

    expect(success, isFalse);
    expect(
      provider.errorMessage,
      'Username is already used by another user.',
    );
  });
}

class _FailingUserService extends UserService {
  _FailingUserService(this.message);

  final String message;

  @override
  Future<UserModel> createUser({
    required String username,
    required String password,
    required String fullName,
    required String email,
    required String phoneNumber,
    required String role,
    String? unitId,
    bool isActive = true,
    bool mustChangePassword = true,
  }) async {
    throw ApiException(statusCode: 409, message: message);
  }

  @override
  Future<UserModel> updateUser({
    required String userId,
    String? username,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? role,
    String? unitId,
    bool? isActive,
    bool? mustChangePassword,
  }) async {
    throw ApiException(statusCode: 409, message: message);
  }
}
