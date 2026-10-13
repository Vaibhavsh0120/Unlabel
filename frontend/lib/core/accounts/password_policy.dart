/// Used only when creating a password or setting a new one. Existing passwords
/// remain valid sign-in inputs, including those created under an older policy.
String? validateNewPassword(String value) {
  if (value.length < 8) return 'Use at least 8 characters.';
  if (!RegExp(r'[A-Za-z]').hasMatch(value) ||
      !RegExp(r'[0-9]').hasMatch(value)) {
    return 'Include a letter and a number.';
  }
  if (isCommonPassword(value)) return 'Choose a less common password.';
  return null;
}

/// A small local deny list, not a claim that a password has been breach-checked.
bool isCommonPassword(String value) =>
    _commonPasswords.contains(value.toLowerCase());

const _commonPasswords = {
  'password1',
  'password123',
  'password1234',
  '12345678',
  '123456789',
  '1234567890',
  'qwerty123',
  'qwerty12345',
  'abc12345',
  'welcome1',
  'welcome123',
  'letmein123',
  'iloveyou1',
  'admin123',
  'unlabel123',
};
