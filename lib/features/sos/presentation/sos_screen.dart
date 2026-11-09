import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/session.dart';
import '../../../core/services/phone_dialer.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_chip.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_section.dart';
import '../../../core/ui/app_type.dart';
import '../../../core/ui/haptics.dart';
import '../../../core/ui/large_title_page.dart';
import '../../../core/utils/formatters.dart';
import '../../coach/presentation/coach_screen.dart';
import '../../diary/domain/craving_entry.dart';
import '../../diary/presentation/diary_controller.dart';
import '../../profile/domain/profile.dart';
import '../../relapse/presentation/relapse_sheet.dart';
import '../../settings/presentation/friend_dialog.dart';
import '../../settings/presentation/settings_controller.dart';

/// Длительность типичной тяги.
const cravingDuration = Duration(minutes: 5);

enum SosResult { overcame, relapsed }

const sosTips = [
  'Выпей стакан холодной воды маленькими глотками',
  'Пройдись или сделай 10 приседаний',
  'Пожуй жвачку или погрызи морковь',
  'Умойся холодной водой',
  'Напиши другу или близкому',
];

Future<void> openSos(BuildContext context, {required Session session}) async {
  final result = await Navigator.of(context).push<SosResult>(
    CupertinoPageRoute(
      fullscreenDialog: true,
      builder: (_) => SosScreen(session: session),
    ),
  );
  if (result == SosResult.relapsed && context.mounted) {
    await showRelapseSheet(
      context,
      profile: session.profile,
      relapses: session.relapses,
    );
  }
}

class SosScreen extends StatefulWidget {
  const SosScreen({super.key, required this.session});

  final Session session;

  Profile get profile => session.profile;
  DiaryController get diary => session.diary;
  SettingsController get settings => session.settings;
  PhoneDialer get dialer => session.services.dialer;

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);
  Timer? _timer;
  Duration _left = cravingDuration;
  Trigger? _trigger;
  String _helped = '';

  @override
  void initState() {
    super.initState();
    // Близкие увидят, что человеку сейчас тяжело (если сервер подключён).
    widget.session.supporters.pingSos();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left <= Duration.zero) return;
      setState(() => _left -= const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breath.dispose();
    super.dispose();
  }

  String get _motivation {
    final p = widget.profile;
    if (p.motivationText.isNotEmpty) return p.motivationText;
    if (p.motivations.isNotEmpty) {
      return p.motivations.map((m) => m.label).join(', ');
    }
    return 'Ты уже далеко зашёл(ла). Не сдавайся сейчас.';
  }

  Future<void> _callFriend() async {
    final messenger = ScaffoldMessenger.of(context);
    var friend = widget.settings.friend;
    if (friend == null) {
      friend = await showFriendDialog(context);
      if (friend == null) return;
      await widget.settings.setFriend(friend);
    }
    final ok = await widget.dialer.call(friend.phone);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось открыть телефон')),
      );
    }
  }

  Future<void> _overcame() async {
    // Берём до await и до pop: после закрытия экрана context уже недействителен.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await widget.diary.add(
      CravingEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        at: DateTime.now(),
        trigger: _trigger,
        overcame: true,
        helped: _helped,
      ),
    );
    if (!mounted) return;
    Haptics.success();
    navigator.pop(SosResult.overcame);
    messenger.showSnackBar(
      const SnackBar(content: Text('Молодец! Ещё одна тяга позади.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final c = context.colors;
    final done = _left <= Duration.zero;
    return ModalPage(
      title: 'Тяга пройдёт',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text((done ? 'Пять минут прошло' : 'Осталось'), style: t.label),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${two(_left.inMinutes)}:${two(_left.inSeconds % 60)}',
              key: const Key('sos-timer'),
              style: t.display.copyWith(fontSize: 96),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            done
                ? 'Тяга должна ослабнуть. Ты справился(ась).'
                : 'Обычно тяга длится 3–5 минут. Просто переживи её.',
            style: t.callout,
          ),
          const SizedBox(height: 32),
          Center(
            child: AnimatedBuilder(
              animation: _breath,
              builder: (context, _) {
                final eased = Curves.easeInOut.transform(_breath.value);
                final size = 96 + 96 * eased;
                final inhale = _breath.status != AnimationStatus.reverse;
                return Column(
                  children: [
                    SizedBox(
                      height: 200,
                      child: Center(
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.ink.withValues(alpha: 0.06 + 0.1 * eased),
                            border: Border.all(color: c.ink, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (inhale ? 'Вдох…' : 'Выдох…'),
                      style: t.label.copyWith(fontSize: 12),
                    ),
                  ],
                );
              },
            ),
          ),
          AppSection(
            padding: const EdgeInsets.only(top: 28),
            header: 'Твоя причина',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text('«$_motivation»', style: t.headline),
              ),
            ],
          ),
          AppSection(
            padding: const EdgeInsets.only(top: 24),
            header: 'Чем отвлечься',
            children: [
              for (var i = 0; i < sosTips.length; i++)
                AppRow(
                  title: sosTips[i],
                  leading: SizedBox(
                    width: 24,
                    child: Text(
                      two(i + 1),
                      style: t.label.copyWith(fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text('ЧТО ВЫЗВАЛО ТЯГУ?', style: t.label),
          ),
          const SizedBox(height: 12),
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
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text('ЧТО ПОМОГЛО?', style: t.label),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in copingActions)
                AppChip(
                  label: a,
                  selected: _helped == a,
                  onTap: () => setState(() => _helped = _helped == a ? '' : a),
                ),
            ],
          ),
          const SizedBox(height: 28),
          AppButton(
            label: 'Поговорить с коучем',
            icon: CupertinoIcons.chat_bubble_2_fill,
            style: AppButtonStyle.outlined,
            onPressed: () => openCoach(context, widget.session),
          ),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: widget.settings,
            builder: (context, _) {
              final f = widget.settings.friend;
              return AppButton(
                label: f == null
                    ? 'Позвонить другу'
                    : 'Позвонить: ${f.displayName}',
                icon: CupertinoIcons.phone_fill,
                style: AppButtonStyle.outlined,
                onPressed: _callFriend,
              );
            },
          ),
          const SizedBox(height: 8),
          AppButton(label: 'Справился(ась)', onPressed: _overcame),
          const SizedBox(height: 4),
          AppButton(
            label: 'Всё же закурил(а)',
            style: AppButtonStyle.text,
            onPressed: () => Navigator.pop(context, SosResult.relapsed),
          ),
        ],
      ),
    );
  }
}
