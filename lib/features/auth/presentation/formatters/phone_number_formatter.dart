import 'package:flutter/services.dart';

/// Removes China's dialing prefix from complete autofilled or pasted numbers.
class PhoneNumberFormatter extends TextInputFormatter {
  const PhoneNumberFormatter();

  static final _separators = RegExp(r'[\s-]');
  static final _phone = RegExp(r'^(?:\+86|0086|86)?(1[3-9]\d{9})$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    final match = _phone.firstMatch(newValue.text.replaceAll(_separators, ''));
    if (match == null) return newValue;
    final phone = match.group(1)!;
    if (phone == newValue.text) return newValue;
    return TextEditingValue(
      text: phone,
      selection: TextSelection.collapsed(offset: phone.length),
    );
  }
}
