import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class AppPhoneField extends StatelessWidget {
  final String initialText;
  final String initialCountryCode;
  final String label;

  /// When true, start validating and showing red error text.
  /// (Set it true after user touches OR after pressing Save)
  final bool showError;

  /// If true, empty should be treated as error (but only when showError=true)
  final bool required;

  final ValueChanged<String> onChangedE164;
  final ValueChanged<bool> onValidChanged;

  const AppPhoneField({
    super.key,
    required this.initialText,
    this.initialCountryCode = 'IN',
    this.label = 'Mobile number',
    required this.onChangedE164,
    required this.onValidChanged,
    this.showError = false,
    this.required = true,
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

      // avoid crash while typing
      disableLengthCheck: true,

      // ✅ Don't validate / show red error until showError=true
      autovalidateMode: showError
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,

      // ✅ This controls the red error text from the package
      validator: (phone) {
        if (!showError) return null;

        final number = (phone?.number ?? '').trim();

        if (required && number.isEmpty) return 'Mobile number is required';
        if (number.isEmpty) return null;

        bool valid = false;
        try {
          valid = phone!.isValidNumber();
        } catch (_) {
          valid = false;
        }
        return valid ? null : 'Enter a valid mobile number';
      },

      onChanged: (phone) {
        onChangedE164(phone.completeNumber);

        final number = phone.number.trim();
        if (number.isEmpty) {
          // Empty => not valid yet (Save should be disabled until valid)
          onValidChanged(false);
          return;
        }

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
