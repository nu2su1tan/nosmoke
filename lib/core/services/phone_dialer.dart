import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/phone.dart';

abstract class PhoneDialer {
  /// Открывает приложение телефона с номером. false — не удалось.
  Future<bool> call(String phone);
}

class UrlLauncherDialer implements PhoneDialer {
  const UrlLauncherDialer();

  @override
  Future<bool> call(String phone) async {
    try {
      return await launchUrl(Uri(scheme: 'tel', path: normalizePhone(phone)));
    } catch (e) {
      debugPrint('Dial failed: $e');
      return false;
    }
  }
}
