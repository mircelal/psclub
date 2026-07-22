import 'package:flutter/services.dart';
import 'phone_utils.dart';

/// +994 prefiksi və 9 rəqəm — hərf və artıq simvol qəbul etmir.
class AzerbaijanPhoneInputFormatter extends TextInputFormatter {
  const AzerbaijanPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cursor = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final beforeCursor = newValue.text.substring(0, cursor);
    var digitsBeforeCursor = beforeCursor.replaceAll(RegExp(r'\D'), '').length;

    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('994')) {
      digits = digits.substring(3);
      digitsBeforeCursor = (digitsBeforeCursor - 3).clamp(0, digits.length);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
      digitsBeforeCursor = (digitsBeforeCursor - 1).clamp(0, digits.length);
    }

    if (digits.length > PhoneUtils.nationalDigitCount) {
      digits = digits.substring(0, PhoneUtils.nationalDigitCount);
    }
    digitsBeforeCursor = digitsBeforeCursor.clamp(0, digits.length);

    final text = '${PhoneUtils.prefix}$digits';
    final selectionOffset =
        (PhoneUtils.prefix.length + digitsBeforeCursor).clamp(PhoneUtils.prefix.length, text.length);

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: selectionOffset),
    );
  }
}
