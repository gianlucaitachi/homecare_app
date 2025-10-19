import 'dart:convert';

import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';

class PasswordService {
  const PasswordService();

  String hashPassword(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  bool verifyPassword(String password, String hashed) {
    if (_looksLikeBcryptHash(hashed)) {
      try {
        return BCrypt.checkpw(password, hashed);
      } on FormatException {
        // Fall through to legacy verification when the stored hash is not a
        // valid bcrypt hash despite matching the expected prefix.
      }
    }

    final legacyHash = sha256.convert(utf8.encode(password)).toString();
    return _constantTimeEquals(legacyHash, hashed);
  }

  bool _looksLikeBcryptHash(String hashed) {
    return hashed.startsWith(r'$2a$') ||
        hashed.startsWith(r'$2b$') ||
        hashed.startsWith(r'$2y$');
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) {
      return false;
    }

    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
