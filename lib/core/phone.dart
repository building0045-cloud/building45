import 'package:flutter/foundation.dart';
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

/// Link that opens WhatsApp directly: the app on phones, WhatsApp Web on
/// desktop. Avoids the wa.me page that asks for one more tap. Without
/// [phone], WhatsApp asks which chat or group to send [text] to.
Uri whatsappUri({String? phone, String? text, required bool mobile}) {
  final query = [
    if (phone != null && phone.isNotEmpty) 'phone=${whatsappNumber(phone)}',
    // Encoded by hand: queryParameters would turn spaces into "+".
    if (text != null && text.isNotEmpty) 'text=${Uri.encodeComponent(text)}',
  ].join('&');
  return Uri.parse(
    mobile ? 'whatsapp://send?$query' : 'https://web.whatsapp.com/send?$query',
  );
}

bool get _isMobile =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Opens WhatsApp on a chat with [phone], or on the chat picker, with
/// [text] ready to send. Returns whether it could be opened.
Future<bool> launchWhatsApp({String? phone, String? text}) async {
  final mobile = _isMobile;
  try {
    return await launchUrl(
      whatsappUri(phone: phone, text: text, mobile: mobile),
      mode: LaunchMode.externalApplication,
      // On a phone browser, navigate the page itself to the app link so
      // WhatsApp opens instead of a blank tab.
      webOnlyWindowName: kIsWeb && mobile ? '_self' : null,
    );
  } catch (_) {
    return false;
  }
}

/// Opens a WhatsApp chat with [phone].
Future<void> openWhatsApp(BuildContext context, String phone) async {
  final messenger = ScaffoldMessenger.of(context);
  if (!await launchWhatsApp(phone: phone)) {
    messenger.showSnackBar(
      SnackBar(content: Text('تعذر فتح واتساب. الرقم: $phone')),
    );
  }
}
