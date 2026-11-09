import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_chip.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_overlays.dart';
import '../../../core/ui/app_section.dart';
import '../../../core/ui/app_text_field.dart';
import '../../../core/ui/app_type.dart';
import '../../../core/ui/large_title_page.dart';
import '../../../core/utils/formatters.dart';
import '../../profile/domain/profile.dart';
import '../domain/craving_entry.dart';
import 'diary_controller.dart';

class DiaryScreen extends StatelessWidget {
  const DiaryScreen({super.key, required this.diary});

  final DiaryController diary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LargeTitlePage(
      title: 'Дневник',
      trailing: Tooltip(
        message: 'Добавить запись',
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => _add(context),
          child: Icon(CupertinoIcons.plus_circle_fill, size: 28, color: c.ink),
        ),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: ListenableBuilder(
            listenable: diary,
            builder: (context, _) {
              final entries = diary.entries;
              if (entries.isEmpty) return const _Empty();
              return Column(
                children: [
                  _Insights(diary: diary),
                  AppSection(
                    header: 'Записи · ${entries.length}',
                    children: [
                      for (final e in entries)
                        Dismissible(
                          key: ValueKey(e.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: c.accent,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            child: Icon(
                              CupertinoIcons.trash,
                              color: c.onAccent,
                            ),
                          ),
                          onDismissed: (_) => diary.remove(e.id),
                          child: ColoredBox(
                            color: c.bg,
                            child: AppRow(
                              leading: StatusDot(
                                color: e.overcame ? c.positive : c.accent,
                              ),
                              title: e.trigger?.label ?? 'Без триггера',
                              subtitle:
                                  '${formatDate(e.at)} ${two(e.at.hour)}:${two(e.at.minute)}'
                                  ' · сила ${e.intensity}/5'
                                  '${e.helped.isEmpty ? '' : ' · помогло: ${e.helped.toLowerCase()}'}'
                                  '${e.note.isEmpty ? '' : '\n${e.note}'}',
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context) async {
    final entry = await showAppSheet<CravingEntry>(
      context,
      builder: (_) => const _EntrySheet(),
    );
    if (entry != null) await diary.add(entry);
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Пока пусто', style: t.headline),
          const SizedBox(height: 8),
          Text(
            'Записей пока нет. Отмечай моменты, когда тянет курить, и '
            'приложение найдёт твои триггеры.',
            style: t.callout,
          ),
        ],
      ),
    );
  }
}

class _Insights extends StatelessWidget {
  const _Insights({required this.diary});

  final DiaryController diary;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final i = diary.insights;
    final String text;
    if (i.topTrigger == null && i.peakHour == null) {
      text = 'Добавь ещё пару записей, и здесь появятся твои закономерности.';
    } else {
      final parts = <String>[
        if (i.topTrigger != null)
          'Чаще всего тянет: ${i.topTrigger!.label.toLowerCase()}.',
        if (i.peakHour != null)
          'Пик тяги около ${two(i.peakHour!)}:00. В это время пришлём напоминание.',
      ];
      text = parts.join('\n');
    }
    return AppSection(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      header: 'Твои закономерности',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(text, style: t.headline.copyWith(fontSize: 19)),
        ),
      ],
    );
  }
}

class _EntrySheet extends StatefulWidget {
  const _EntrySheet();

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  Trigger? _trigger;
  double _intensity = 3;
  bool _overcame = true;
  String _helped = '';
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetTitle('Новая запись'),
          const SizedBox(height: 8),
          Text('ЧТО ВЫЗВАЛО ТЯГУ?', style: t.label),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tr in Trigger.values)
                AppChip(
                  label: tr.label,
                  selected: _trigger == tr,
                  onTap: () =>
                      setState(() => _trigger = _trigger == tr ? null : tr),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('СИЛА ТЯГИ', style: t.label),
              const Spacer(),
              Text('${_intensity.round()}/5', style: t.bodyStrong),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlider(
              value: _intensity,
              min: 1,
              max: 5,
              divisions: 4,
              activeColor: c.ink,
              onChanged: (v) => setState(() => _intensity = v),
            ),
          ),
          Row(
            children: [
              Expanded(child: Text('Справился(ась)', style: t.body)),
              CupertinoSwitch(
                value: _overcame,
                activeTrackColor: c.positive,
                onChanged: (v) => setState(() => _overcame = v),
              ),
            ],
          ),
          if (_overcame) ...[
            const SizedBox(height: 16),
            Text('ЧТО ПОМОГЛО?', style: t.label),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in copingActions)
                  AppChip(
                    label: a,
                    selected: _helped == a,
                    onTap: () =>
                        setState(() => _helped = _helped == a ? '' : a),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          AppTextField(
            controller: _note,
            label: 'Заметка',
            placeholder: 'Необязательно',
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Сохранить',
            onPressed: () => Navigator.pop(
              context,
              CravingEntry(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                at: DateTime.now(),
                trigger: _trigger,
                intensity: _intensity.round(),
                overcame: _overcame,
                helped: _overcame ? _helped : '',
                note: _note.text.trim(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
