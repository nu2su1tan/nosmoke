import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_chip.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_overlays.dart';
import '../../../core/ui/app_progress_bar.dart';
import '../../../core/ui/app_section.dart';
import '../../../core/ui/app_text_field.dart';
import '../../../core/ui/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/number_parsing.dart';
import '../../profile/domain/currencies.dart';
import '../../profile/domain/profile.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final ValueChanged<Profile> onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _totalSteps = 8;
  final _page = PageController();
  int _step = 0;

  // Ответы с разумными значениями по умолчанию.
  int _cigsPerDay = 15;
  final _priceCtrl = TextEditingController(text: '2000');
  int _cigsPerPack = 20;
  int _years = 5;
  String? _currency; // выбранный чип
  final _customCurrencyCtrl = TextEditingController();
  bool _customCurrency = false;
  final Set<Trigger> _triggers = {};
  final Set<Motivation> _motivations = {};
  final _motivationCtrl = TextEditingController();
  QuitMode _mode = QuitMode.cold;
  DateTime _quitDate = dateOnly(DateTime.now());

  @override
  void dispose() {
    _page.dispose();
    _priceCtrl.dispose();
    _customCurrencyCtrl.dispose();
    _motivationCtrl.dispose();
    super.dispose();
  }

  double get _price => parseDecimal(_priceCtrl.text) ?? 0;

  String get _currencyValue =>
      (_customCurrency ? _customCurrencyCtrl.text : _currency ?? '').trim();

  /// Цена и валюта обязательны: без них не посчитать экономию.
  bool get _canContinue => switch (_step) {
    2 => _price > 0 && _currencyValue.isNotEmpty,
    _ => true,
  };

  Profile _buildProfile() => Profile(
    cigsPerDay: _cigsPerDay,
    packPrice: _price,
    cigsPerPack: _cigsPerPack,
    yearsSmoking: _years,
    triggers: _triggers,
    motivations: _motivations,
    motivationText: _motivationCtrl.text.trim(),
    quitMode: _mode,
    quitDate: dateOnly(_quitDate),
    currency: _currencyValue,
  );

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step == _totalSteps - 1) {
      widget.onDone(_buildProfile());
      return;
    }
    _page.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() => _page.previousPage(
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
  );

  String get _buttonLabel {
    if (_step == 0) return 'Начать';
    if (_step == _totalSteps - 1) return 'Я готов';
    final skippable = _step == 4
        ? _triggers.isEmpty
        : _step == 5
        ? _motivations.isEmpty && _motivationCtrl.text.isEmpty
        : false;
    return skippable ? 'Пропустить' : 'Дальше';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: _step > 0
                          ? CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: _back,
                              child: Icon(
                                CupertinoIcons.chevron_back,
                                color: c.ink,
                              ),
                            )
                          : null,
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        '${two(_step + 1)} / ${two(_totalSteps)}',
                        style: t.label,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppProgressBar(value: (_step + 1) / _totalSteps),
            ),
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _welcome(),
                  _cigsStep(),
                  _priceStep(),
                  _yearsStep(),
                  _triggersStep(),
                  _motivationStep(),
                  _modeStep(),
                  _summaryStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: AppButton(
                label: _buttonLabel,
                onPressed: _canContinue ? _next : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Шаги ----------

  Widget _stepPage({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    final t = context.type;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.title),
          if (subtitle != null) ...[
            const SizedBox(height: 12),
            Text(subtitle, style: t.callout),
          ],
          const SizedBox(height: 32),
          child,
        ],
      ),
    );
  }

  Widget _welcome() {
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('NOSMOKE', style: t.label),
          const SizedBox(height: 16),
          Text(
            'Ты уже сделал первый шаг',
            style: t.display.copyWith(
              fontSize: 52,
              letterSpacing: -2.4,
              height: 1,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Ответь на несколько вопросов, и мы составим план именно для '
            'тебя. Это займёт пару минут.',
            style: t.callout,
          ),
        ],
      ),
    );
  }

  /// Гигантское число с подписью и ползунком.
  Widget _bigNumber({
    required String unit,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('$value', style: t.display),
            const SizedBox(width: 12),
            Text(unit, style: t.headline.copyWith(fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: CupertinoSlider(
            value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            activeColor: context.colors.ink,
            onChanged: (v) => setState(() => onChanged(v.round())),
          ),
        ),
      ],
    );
  }

  Widget _cigsStep() => _stepPage(
    title: 'Сколько сигарет в день ты куришь?',
    child: _bigNumber(
      unit: 'в день',
      value: _cigsPerDay,
      min: 1,
      max: 60,
      onChanged: (v) => _cigsPerDay = v,
    ),
  );

  Widget _priceStep() => _stepPage(
    title: 'Сколько стоит пачка?',
    subtitle: 'Так мы посчитаем, сколько денег ты сэкономишь.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          fieldKey: const Key('price-field'),
          controller: _priceCtrl,
          label: 'Цена пачки',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        Text('ВАЛЮТА', style: context.type.label),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final cur in currencyOptions)
              AppChip(
                label: cur,
                selected: !_customCurrency && _currency == cur,
                onTap: () => setState(() {
                  _customCurrency = false;
                  _currency = cur;
                }),
              ),
            AppChip(
              label: 'Другая',
              selected: _customCurrency,
              onTap: () => setState(() => _customCurrency = true),
            ),
          ],
        ),
        if (_customCurrency) ...[
          const SizedBox(height: 16),
          AppTextField(
            fieldKey: const Key('custom-currency'),
            controller: _customCurrencyCtrl,
            label: 'Своя валюта',
            placeholder: 'Например, сом',
            maxLength: 5,
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 32),
        _bigNumber(
          unit: 'сигарет в пачке',
          value: _cigsPerPack,
          min: 10,
          max: 30,
          onChanged: (v) => _cigsPerPack = v,
        ),
      ],
    ),
  );

  Widget _yearsStep() => _stepPage(
    title: 'Сколько лет ты куришь?',
    child: _bigNumber(
      unit: 'лет',
      value: _years,
      min: 0,
      max: 50,
      onChanged: (v) => _years = v,
    ),
  );

  Widget _chips<T>(List<T> values, Set<T> selected, String Function(T) label) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final v in values)
            AppChip(
              label: label(v),
              selected: selected.contains(v),
              onTap: () => setState(
                () =>
                    selected.contains(v) ? selected.remove(v) : selected.add(v),
              ),
            ),
        ],
      );

  Widget _triggersStep() => _stepPage(
    title: 'Когда тянет сильнее всего?',
    subtitle:
        'Выбери всё, что подходит. Это можно пропустить и дополнить позже.',
    child: _chips(Trigger.values, _triggers, (t) => t.label),
  );

  Widget _motivationStep() => _stepPage(
    title: 'Почему ты хочешь бросить?',
    subtitle: 'Мы покажем это в трудную минуту.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _chips(Motivation.values, _motivations, (m) => m.label),
        const SizedBox(height: 24),
        AppTextField(
          controller: _motivationCtrl,
          label: 'Своими словами',
          placeholder: 'Необязательно',
          maxLines: 3,
          maxLength: 200,
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
  );

  Widget _modeStep() => _stepPage(
    title: 'Как будем бросать?',
    child: Column(
      children: [
        _ChoiceRow(
          title: 'Сразу',
          subtitle: 'С выбранной даты ни одной сигареты',
          selected: _mode == QuitMode.cold,
          onTap: () => setState(() => _mode = QuitMode.cold),
        ),
        const Hairline(),
        _ChoiceRow(
          title: 'Постепенно',
          subtitle: 'Каждую неделю меньше, пока не дойдём до нуля',
          selected: _mode == QuitMode.gradual,
          onTap: () => setState(() => _mode = QuitMode.gradual),
        ),
        const Hairline(),
        AppRow(
          title: 'Дата старта',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatDate(_quitDate),
                style: context.type.body.copyWith(
                  color: context.colors.inkSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: context.colors.inkTertiary,
              ),
            ],
          ),
          onTap: _pickDate,
        ),
      ],
    ),
  );

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    // Если приложение открыто с прошлых суток, дата могла устареть.
    var picked = _quitDate.isBefore(today) ? today : _quitDate;
    final result = await showAppSheet<DateTime>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          children: [
            const SheetTitle('Дата старта'),
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: picked,
                minimumDate: today,
                maximumDate: today.add(const Duration(days: 365)),
                onDateTimeChanged: (d) => picked = d,
              ),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Готово',
              onPressed: () => Navigator.pop(ctx, picked),
            ),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _quitDate = dateOnly(result));
  }

  Widget _summaryStep() {
    final p = _buildProfile();
    final t = context.type;
    final why = p.motivationText.isNotEmpty
        ? p.motivationText
        : p.motivations.map((m) => m.label).join(', ');
    return _stepPage(
      title: 'Твой план готов',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSection(
            padding: EdgeInsets.zero,
            children: [
              _SummaryRow('Старт', formatDate(p.quitDate)),
              _SummaryRow(
                'Способ',
                p.quitMode == QuitMode.cold ? 'Сразу' : 'Постепенно',
              ),
              if (p.quitMode == QuitMode.gradual)
                _SummaryRow('По неделям', p.gradualSchedule.join(' → ')),
              _SummaryRow('Сэкономишь за месяц', p.money(p.monthlySavings)),
              _SummaryRow('Сэкономишь за год', p.money(p.yearlySavings)),
              if (why.isNotEmpty) _SummaryRow('Твоя причина', why),
            ],
          ),
          if (p.suggestDoctor)
            AppSection(
              padding: const EdgeInsets.only(top: 24),
              header: 'Совет',
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'При таком стаже и количестве сигарет стоит обсудить с '
                    'врачом никотинзаместительную терапию. '
                    'Это повышает шансы на успех.',
                    style: t.callout,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppRow(
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? c.ink : Colors.transparent,
          border: Border.all(color: selected ? c.ink : c.hairline, width: 1.5),
        ),
        child: selected
            ? Icon(CupertinoIcons.check_mark, size: 13, color: c.bg)
            : null,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.label),
          const SizedBox(height: 6),
          Text(value, style: t.headline),
        ],
      ),
    );
  }
}
