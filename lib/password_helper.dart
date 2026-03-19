import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

String hashPassword(String password) {
  final random = Random.secure();
  final saltBytes = List.generate(32, (_) => random.nextInt(256));
  final salt = base64Url.encode(saltBytes);
  final hash = sha256.convert(utf8.encode('$salt:$password')).toString();
  return '$salt:$hash';
}

bool verifyPassword(String password, String storedHash) {
  final idx = storedHash.indexOf(':');
  if (idx == -1) return false;
  final salt = storedHash.substring(0, idx);
  final expectedHash = storedHash.substring(idx + 1);
  final actualHash = sha256.convert(utf8.encode('$salt:$password')).toString();
  return actualHash == expectedHash;
}
