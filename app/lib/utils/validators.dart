class Validators {
  const Validators._();

  static String? requiredText(String value, String message) {
    if (value.trim().isEmpty) return message;
    return null;
  }

  static String? cnic(String value) {
    if (value.trim().isEmpty) return 'Enter your CNIC';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 13) return 'CNIC must be 13 digits';
    return null;
  }

  static String? password(String value) {
    if (value.isEmpty) return 'Enter your password';
    if (value.length < 8) return 'Use at least 8 characters';
    return null;
  }

  static String? mobile(String value) {
    if (value.trim().isEmpty) return 'Enter your mobile number';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 11) return 'Enter a valid mobile number';
    return null;
  }
}
