import 'package:flutter_test/flutter_test.dart';
import 'package:inmobarco_app/domain/models/user.dart';

void main() {
  group('User.fromJson', () {
    test('parses all fields', () {
      final user = User.fromJson({
        'username': 'jbarco',
        'role': 'admin',
        'first_name': 'Juan',
        'last_name': 'Barco',
        'phone': '3001234567',
      });

      expect(user.username, 'jbarco');
      expect(user.role, 'admin');
      expect(user.firstName, 'Juan');
      expect(user.lastName, 'Barco');
      expect(user.phone, '3001234567');
    });

    test('handles null/missing fields with defaults', () {
      final user = User.fromJson({});

      expect(user.username, '');
      expect(user.role, '');
      expect(user.firstName, '');
      expect(user.lastName, '');
      expect(user.phone, '');
    });
  });

  group('User.toJson roundtrip', () {
    test('preserves all fields', () {
      final original = User.fromJson({
        'username': 'test',
        'role': 'agent',
        'first_name': 'Ana',
        'last_name': 'García',
        'phone': '3109876543',
      });

      final json = original.toJson();
      final restored = User.fromJson(json);

      expect(restored.username, original.username);
      expect(restored.role, original.role);
      expect(restored.firstName, original.firstName);
      expect(restored.lastName, original.lastName);
      expect(restored.phone, original.phone);
    });
  });

  group('User computed properties', () {
    test('fullName combines first and last name', () {
      final user = User(
        username: 'test',
        role: 'admin',
        firstName: 'Juan',
        lastName: 'Barco',
      );
      expect(user.fullName, 'Juan Barco');
    });

    test('fullName handles empty last name', () {
      final user = User(
        username: 'test',
        role: 'admin',
        firstName: 'Juan',
        lastName: '',
      );
      expect(user.fullName, 'Juan');
    });

    test('fullName handles empty first name', () {
      final user = User(
        username: 'test',
        role: 'admin',
        firstName: '',
        lastName: 'Barco',
      );
      expect(user.fullName, 'Barco');
    });

    test('toString contains user info', () {
      final user = User(
        username: 'jbarco',
        role: 'admin',
        firstName: 'Juan',
        lastName: 'Barco',
      );
      expect(user.toString(), contains('jbarco'));
      expect(user.toString(), contains('Juan'));
    });
  });
}
