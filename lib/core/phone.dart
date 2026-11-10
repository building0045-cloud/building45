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

/// International number for WhatsApp links; Egyptian local numbers
/// (01xxxxxxxxx) get the 20 country code.
String whatsappNumber(String phone) {
  var d = dialableNumber(phone);
  if (d.startsWith('+')) return d.substring(1);
  if (d.startsWith('00')) return d.substring(2);
  if (d.startsWith('0') && d.length == 11) d = '20${d.substring(1)}';
  return d;
}

/// Opens a WhatsApp chat with [phone].
Future<void> openWhatsApp(BuildContext context, String phone) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.https('wa.me', '/${whatsappNumber(phone)}');
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!opened) {
    messenger.showSnackBar(
      SnackBar(content: Text('تعذر فتح واتساب. الرقم: $phone')),
    );
  }
}
