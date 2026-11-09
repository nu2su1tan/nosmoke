import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

abstract class ShareService {
  Future<void> shareText(String text);
}

class SharePlusService implements ShareService {
  const SharePlusService();

  @override
  Future<void> shareText(String text) async {
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (e) {
      debugPrint('Share failed: $e');
    }
  }
}
