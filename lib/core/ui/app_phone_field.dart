import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class AppPhoneField extends StatelessWidget {
  final String initialText;
  final String initialCountryCode;
  final String label;

  final ValueChanged<String> onChangedE164;
  final ValueChanged<bool> onValidChanged;

  const AppPhoneField({
    super.key,
    required this.initialText,
    this.initialCountryCode = 'IN',
    this.label = 'Mobile number',
    required this.onChangedE164,
    required this.onValidChanged,
  });

  @override
  Widget build(BuildContext context) {
    return IntlPhoneField(
      initialCountryCode: initialCountryCode,
      initialValue: initialText,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.phone),
      ),

      // avoid hard crash while typing
      disableLengthCheck: true,

      onChanged: (phone) {
        onChangedE164(phone.completeNumber);

        bool valid = false;
        try {
          valid = phone.isValidNumber();
        } catch (_) {
          valid = false;
        }
        onValidChanged(valid);
      },
    );
  }
}
