import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class AppPhoneField extends StatelessWidget {
  final String initialText; // national number only
  final String initialCountryCode; // "IN"
  final ValueChanged<String> onChangedE164; // +9198xxxx
  final ValueChanged<String>? onChangedNational; // 98xxxx
  final String label;

  const AppPhoneField({
    super.key,
    required this.initialText,
    this.initialCountryCode = 'IN',
    required this.onChangedE164,
    this.onChangedNational,
    this.label = 'Mobile number',
  });

  @override
  Widget build(BuildContext context) {
    return IntlPhoneField(
      initialCountryCode: initialCountryCode,
      initialValue: initialText,
      disableLengthCheck: false,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.phone),
      ),
      dropdownIconPosition: IconPosition.trailing,
      onChanged: (phone) {
        // phone.completeNumber => +91XXXXXXXXXX
        // phone.number => national part
        onChangedE164(phone.completeNumber);
        onChangedNational?.call(phone.number);
      },
      onCountryChanged: (_) {},
    );
  }
}
