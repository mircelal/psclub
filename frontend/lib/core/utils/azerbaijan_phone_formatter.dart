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
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('994')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    if (digits.length > PhoneUtils.nationalDigitCount) {
      digits = digits.substring(0, PhoneUtils.nationalDigitCount);
    }

    final text = '${PhoneUtils.prefix}$digits';
    final selectionOffset = text.length.clamp(PhoneUtils.prefix.length, text.length);

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: selectionOffset),
    );
  }
}
