import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _arabicDigits = '٠١٢٣٤٥٦٧٨٩';

/// Digits (and a leading +) of [phone], with Arabic-Indic digits converted.
String dialableNumber(String phone) {
  final buffer = StringBuffer();
  for (final ch in phone.split('')) {
    final arabic = _arabicDigits.indexOf(ch);
    if (arabic >= 0) {
      buffer.write(arabic);
    } else if (RegExp(r'\d').hasMatch(ch) || (ch == '+' && buffer.isEmpty)) {
      buffer.write(ch);
    }
  }
  return buffer.toString();
}

/// Opens the device dialer for [phone].
Future<void> callPhone(BuildContext context, String phone) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri(scheme: 'tel', path: dialableNumber(phone));
  var opened = false;
  try {
    opened = await launchUrl(uri);
  } catch (_) {}
  if (!opened) {
    messenger.showSnackBar(
      SnackBar(content: Text('تعذر فتح الاتصال. الرقم: $phone')),
    );
  }
}
