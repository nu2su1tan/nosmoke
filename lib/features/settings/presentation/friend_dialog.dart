import 'package:flutter/cupertino.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_type.dart';
import '../../../core/utils/phone.dart';
import '../domain/friend.dart';

/// Нативный iOS-диалог ввода контакта друга. Возвращает null при отмене.
Future<Friend?> showFriendDialog(BuildContext context, {Friend? initial}) {
  return showCupertinoDialog<Friend>(
    context: context,
    builder: (_) => _FriendDialog(initial: initial),
  );
}

class _FriendDialog extends StatefulWidget {
  const _FriendDialog({this.initial});

  final Friend? initial;

  @override
  State<_FriendDialog> createState() => _FriendDialogState();
}

class _FriendDialogState extends State<_FriendDialog> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _phone = TextEditingController(text: widget.initial?.phone ?? '');
  bool _showError = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    if (!isValidPhone(_phone.text)) {
      setState(() => _showError = true);
      return;
    }
    Navigator.pop(
      context,
      Friend(name: _name.text.trim(), phone: normalizePhone(_phone.text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return CupertinoAlertDialog(
      title: const Text('Кому звонить в трудную минуту?'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            CupertinoTextField(
              key: const Key('friend-name'),
              controller: _name,
              placeholder: 'Имя',
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              key: const Key('friend-phone'),
              controller: _phone,
              placeholder: 'Телефон',
              keyboardType: TextInputType.phone,
            ),
            if (_showError) ...[
              const SizedBox(height: 8),
              Text(
                'Введи корректный номер',
                style: t.caption.copyWith(color: c.accent),
              ),
            ],
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _save,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
