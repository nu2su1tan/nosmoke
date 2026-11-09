import 'package:flutter/cupertino.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_type.dart';
import 'account_controller.dart';

String connectErrorText(ConnectError e) => switch (e) {
  ConnectError.invalidUrl => 'Неверный адрес сервера.',
  ConnectError.network => 'Не удалось связаться с сервером.',
  ConnectError.server => 'Сервер ответил ошибкой.',
};

/// Диалог подключения к серверу сообщества. Возвращает true при успехе.
Future<bool> showServerDialog(
  BuildContext context,
  AccountController account,
) async {
  final ok = await showCupertinoDialog<bool>(
    context: context,
    builder: (_) => _ServerDialog(account: account),
  );
  return ok ?? false;
}

class _ServerDialog extends StatefulWidget {
  const _ServerDialog({required this.account});

  final AccountController account;

  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  late final _url = TextEditingController(
    text: widget.account.account?.baseUrl ?? '',
  );
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.account.connect(_url.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = connectErrorText(widget.account.error ?? ConnectError.server);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return CupertinoAlertDialog(
      title: const Text('Сервер сообщества'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            const Text(
              'Нужен для ленты, близких и ИИ-коуча. Подключение анонимное.',
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              key: const Key('server-url'),
              controller: _url,
              placeholder: 'https://адрес-сервера',
              keyboardType: TextInputType.url,
              autocorrect: false,
            ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const CupertinoActivityIndicator(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: t.caption.copyWith(color: c.accent)),
            ],
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _busy ? null : _connect,
          child: const Text('Подключить'),
        ),
      ],
    );
  }
}
