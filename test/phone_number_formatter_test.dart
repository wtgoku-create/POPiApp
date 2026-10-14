import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/auth/presentation/formatters/phone_number_formatter.dart';

void main() {
  const formatter = PhoneNumberFormatter();

  for (final value in [
    '+8613800138000',
    '+86 138 0013 8000',
    '+86\u00a0138-0013-8000',
    '0086 13800138000',
    '8613800138000',
    '138-0013-8000',
  ]) {
    test('normalizes $value before the eleven-digit limit', () {
      final normalized = formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        ),
      );
      final limited = LengthLimitingTextInputFormatter(
        11,
      ).formatEditUpdate(TextEditingValue.empty, normalized);
      expect(limited.text, '13800138000');
      expect(limited.selection, const TextSelection.collapsed(offset: 11));
      expect(limited.composing, TextRange.empty);
    });
  }

  test('preserves ordinary editing, deletion and invalid phone numbers', () {
    for (final value in [
      '',
      '138',
      '13800138000',
      '86138001380',
      '+86',
      '+86138001380001',
      '+4413800138000',
      '+8612800138000',
    ]) {
      final edit = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length ~/ 2),
      );
      expect(
        formatter.formatEditUpdate(TextEditingValue.empty, edit),
        same(edit),
      );
    }
  });

  test('does not rewrite an active composing range', () {
    const edit = TextEditingValue(
      text: '+8613800138000',
      selection: TextSelection.collapsed(offset: 14),
      composing: TextRange(start: 0, end: 14),
    );
    expect(
      formatter.formatEditUpdate(TextEditingValue.empty, edit),
      same(edit),
    );
  });
}
