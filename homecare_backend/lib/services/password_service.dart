import 'package:bcrypt/bcrypt.dart';

class PasswordService {
  const PasswordService();

  String hashPassword(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  bool verifyPassword(String password, String hashed) {
    return BCrypt.checkpw(password, hashed);
  }
}
