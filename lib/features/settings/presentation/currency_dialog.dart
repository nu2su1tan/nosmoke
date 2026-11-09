import 'package:flutter/cupertino.dart';

import '../../../core/ui/app_chip.dart';
import '../../profile/domain/currencies.dart';

/// Нативный диалог выбора валюты: быстрые варианты или своя.
/// Возвращает null при отмене.
Future<String?> showCurrencyDialog(BuildContext context, String current) {
  return showCupertinoDialog<String>(
    context: context,
    builder: (_) => _CurrencyDialog(current: current),
  );
}

class _CurrencyDialog extends StatefulWidget {
  const _CurrencyDialog({required this.current});

  final String current;

  @override
  State<_CurrencyDialog> createState() => _CurrencyDialogState();
}

class _CurrencyDialogState extends State<_CurrencyDialog> {
  late final _ctrl = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _ctrl.text.trim();
    return CupertinoAlertDialog(
      title: const Text('Валюта'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in currencyOptions)
                  AppChip(
                    label: c,
                    selected: value == c,
                    onTap: () => setState(() => _ctrl.text = c),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              key: const Key('currency-field'),
              controller: _ctrl,
              placeholder: 'Своя валюта',
              maxLength: 5,
              onChanged: (_) => setState(() {}),
            ),
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
          onPressed: value.isEmpty ? null : () => Navigator.pop(context, value),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
