import 'package:flutter/material.dart';

class AppConfirmDialog {
  static Future<bool> show(
      BuildContext context, {
        required String title,
        required String message,
        String cancelText = 'Cancel',
        String confirmText = 'OK',
        bool isDanger = false,
      }) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: isDanger
                ? FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            )
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return res ?? false;
  }
}
