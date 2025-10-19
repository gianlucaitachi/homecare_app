// lib/models.dart
import 'package:uuid/uuid.dart';
import 'package:bcrypt/bcrypt.dart';

final uuid = Uuid();

class User {
  String id;
  String name;
  String email;
  String passwordHash;
  String familyId;
  User({required this.id, required this.name, required this.email, required this.passwordHash, required this.familyId});
}

final Map<String, User> users = {}; // key: email -> user
final Map<String, String> userById = {}; // id -> email
