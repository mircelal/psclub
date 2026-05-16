import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/azerbaijan_phone_formatter.dart';
import '../utils/phone_utils.dart';

/// Azərbaycan telefonu: yalnız +994 və 9 rəqəm.
class PhoneTextField extends StatelessWidget {
  const PhoneTextField({
    super.key,
    required this.controller,
    this.label = 'Telefon',
    this.autofocus = false,
    this.showHelper = true,
  });

  final TextEditingController controller;
  final String? label;
  final bool autofocus;
  final bool showHelper;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: const [
        AzerbaijanPhoneInputFormatter(),
      ],
      maxLength: PhoneUtils.fullLength,
      buildCounter: (_, {required currentLength, required isFocused, required maxLength}) => null,
      style: const TextStyle(fontSize: 15, letterSpacing: 0.3),
      decoration: InputDecoration(
        labelText: label,
        hintText: PhoneUtils.displayHint(),
        prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: AppColors.textMuted),
        helperText: showHelper ? 'Yalnız rəqəm · ${PhoneUtils.nationalDigitCount} rəqəm (+994-dən sonra)' : null,
        helperMaxLines: 2,
      ),
    );
  }
}
