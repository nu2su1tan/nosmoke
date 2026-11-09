import 'package:flutter/cupertino.dart';

import '../../../app/session.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_overlays.dart';
import '../../../core/ui/app_text_field.dart';
import '../../../core/utils/number_parsing.dart';
import '../domain/savings_goal.dart';

/// Шит «Цель»: название и сумма. Для существующей цели есть «Удалить».
Future<void> showGoalSheet(BuildContext context, Session session) async {
  final result = await showAppSheet<_GoalResult>(
    context,
    builder: (_) => _GoalSheet(
      initial: session.goals.goal,
      currency: session.profile.currency,
    ),
  );
  if (result == null) return;
  if (result.delete) {
    await session.goals.clear();
  } else {
    await session.goals.set(result.goal!);
  }
}

class _GoalResult {
  const _GoalResult.save(SavingsGoal this.goal) : delete = false;
  const _GoalResult.delete() : goal = null, delete = true;

  final SavingsGoal? goal;
  final bool delete;
}

class _GoalSheet extends StatefulWidget {
  const _GoalSheet({this.initial, required this.currency});

  final SavingsGoal? initial;
  final String currency;

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _amount = TextEditingController(
    text: widget.initial == null
        ? ''
        : widget.initial!.target.round().toString(),
  );

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  double? get _target => parseDecimal(_amount.text);

  bool get _valid => _title.text.trim().isNotEmpty && (_target ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetTitle(
            widget.initial == null ? 'Новая цель' : 'Цель',
            subtitle: 'На что хочешь потратить сэкономленные деньги?',
          ),
          const SizedBox(height: 12),
          AppTextField(
            fieldKey: const Key('goal-title'),
            controller: _title,
            label: 'Название',
            placeholder: 'Например, кроссовки',
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          AppTextField(
            fieldKey: const Key('goal-amount'),
            controller: _amount,
            label: widget.currency.isEmpty
                ? 'Сумма'
                : 'Сумма, ${widget.currency}',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Сохранить',
            onPressed: _valid
                ? () => Navigator.pop(
                    context,
                    _GoalResult.save(
                      SavingsGoal(
                        title: _title.text.trim(),
                        target: _target!,
                        createdAt: widget.initial?.createdAt ?? DateTime.now(),
                      ),
                    ),
                  )
                : null,
          ),
          if (widget.initial != null)
            AppButton(
              label: 'Удалить цель',
              style: AppButtonStyle.text,
              onPressed: () =>
                  Navigator.pop(context, const _GoalResult.delete()),
            ),
        ],
      ),
    );
  }
}
