import '../models/user.dart';

class UserState {
  User? currentUser;

  UserState() {
    currentUser = User(
      id: '1',
      email: 'test@example.com',
      createdAt: DateTime.now(),
    );
  }
}
