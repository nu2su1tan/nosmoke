import 'package:flutter/cupertino.dart';

import '../../../app/session.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_type.dart';
import '../../account/presentation/server_dialog.dart';

/// Заглушка для разделов, которым нужен сервер.
class ConnectPrompt extends StatelessWidget {
  const ConnectPrompt({
    super.key,
    required this.session,
    required this.title,
    required this.body,
  });

  final Session session;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.headline),
          const SizedBox(height: 8),
          Text(body, style: t.callout),
          const SizedBox(height: 16),
          AppButton(
            key: const Key('connect-server'),
            label: 'Подключить сервер',
            style: AppButtonStyle.outlined,
            compact: true,
            expand: false,
            onPressed: () => showServerDialog(context, session.account),
          ),
        ],
      ),
    );
  }
}
