import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  return AuthController();
});

class AuthController extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _email;

  bool get isLoggedIn => _isLoggedIn;
  String? get email => _email;

  Future<void> login({required String email}) async {
    _isLoggedIn = true;
    _email = email;
    notifyListeners();
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _email = null;
    notifyListeners();
  }
}
