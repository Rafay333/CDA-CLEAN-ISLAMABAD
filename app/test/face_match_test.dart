import 'package:cda_clean_islamabad/features/hr/face_match.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts attendance from 60% upward', () {
    expect(isStrongFaceMatch(59), isFalse);
    expect(isStrongFaceMatch(60), isTrue);
    expect(isStrongFaceMatch(84), isTrue);
  });

  test('splits this-employee vs duplicate-other enroll errors', () {
    expect(isThisEmployeeAlreadyEnrolledError('Face already registered.'), isTrue);
    expect(
      isDuplicateOfOtherEmployeeError(
        'This face is already registered under Ahmed Raza (3520).',
      ),
      isTrue,
    );
    expect(isThisEmployeeAlreadyEnrolledError(
      'This face is already registered under Ahmed Raza (3520).',
    ), isFalse);
    expect(isAlreadyRegisteredError('Face registered successfully.'), isFalse);
  });
}
