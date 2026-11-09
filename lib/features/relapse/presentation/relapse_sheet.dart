import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_overlays.dart';
import '../../../core/ui/app_text_field.dart';
import '../../../core/ui/app_type.dart';
import '../../profile/domain/profile.dart';
import '../../progress/domain/progress.dart';
import '../domain/relapse.dart';
import 'relapse_controller.dart';

/// Мягкий сценарий срыва: без стыда, прогресс не обнуляется.
Future<void> showRelapseSheet(
  BuildContext context, {
  required Profile profile,
  required RelapseController relapses,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await showAppSheet<Relapse>(
    context,
    builder: (_) => const _RelapseSheet(),
  );
  if (result == null) return;
  await relapses.add(result);
  final s = computeProgress(profile, relapses.items, DateTime.now());
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        'Это часть пути. Ты уже ${s.daysInProgram} дн. в программе, '
        'сэкономлено ${profile.money(s.moneySaved)}. Продолжаем!',
      ),
    ),
  );
}

class _RelapseSheet extends StatefulWidget {
  const _RelapseSheet();

  @override
  State<_RelapseSheet> createState() => _RelapseSheetState();
}

class _RelapseSheetState extends State<_RelapseSheet> {
  int _count = 1;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text('Бывает. Это не конец', style: t.title.copyWith(fontSize: 28)),
          const SizedBox(height: 12),
          Text(
            'Срыв не обнуляет твой прогресс. Дни в программе, деньги и '
            'достижения остаются с тобой. Важно понять, что пошло не так, '
            'и продолжить.',
            style: t.callout,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Text('Сколько сигарет выкурено?', style: t.body)),
              _RoundIconButton(
                icon: CupertinoIcons.minus,
                onPressed: _count > 1 ? () => setState(() => _count--) : null,
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '$_count',
                  textAlign: TextAlign.center,
                  style: t.numeral.copyWith(fontSize: 24),
                ),
              ),
              _RoundIconButton(
                icon: CupertinoIcons.plus,
                onPressed: () => setState(() => _count++),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppTextField(
            controller: _note,
            label: 'Что спровоцировало?',
            placeholder: 'Необязательно',
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Записать и продолжить',
            onPressed: () => Navigator.pop(
              context,
              Relapse(
                at: DateTime.now(),
                count: _count,
                note: _note.text.trim(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Opacity(
      opacity: onPressed == null ? 0.3 : 1,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: onPressed,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c.hairline, width: 1.2),
          ),
          child: Icon(icon, size: 16, color: c.ink),
        ),
      ),
    );
  }
}
