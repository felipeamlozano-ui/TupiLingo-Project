import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Lesson status normalization and flow tests', () {
    test('Normalizes PT and EN statuses correctly', () {
      String normalize(String raw) {
        switch (raw.toLowerCase()) {
          case 'correct':
          case 'correto':
            return 'correct';
          case 'almost':
          case 'quase_certo':
            return 'almost';
          case 'wrong':
          case 'errado':
          default:
            return 'wrong';
        }
      }

      expect(normalize('correct'), 'correct');
      expect(normalize('CORRETO'), 'correct');
      expect(normalize('almost'), 'almost');
      expect(normalize('QUASE_CERTO'), 'almost');
      expect(normalize('wrong'), 'wrong');
      expect(normalize('ERRADO'), 'wrong');
      expect(normalize('anything_else'), 'wrong');
    });
  });
}
