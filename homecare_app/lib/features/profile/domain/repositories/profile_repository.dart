import 'package:homecare_app/features/auth/domain/entities/user.dart';

abstract class ProfileRepository {
  Future<User> updateCurrentUser({required String name, required String email});
}
