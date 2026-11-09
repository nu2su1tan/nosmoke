import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_overlays.dart';
import '../../../core/ui/app_section.dart';
import '../../../core/ui/app_type.dart';
import '../../../core/ui/haptics.dart';
import '../../../core/ui/large_title_page.dart';
import '../../../core/utils/formatters.dart';
import '../../profile/domain/profile.dart';
import '../../account/presentation/account_controller.dart';
import '../../account/presentation/server_dialog.dart';
import '../../plan/presentation/paywall_screen.dart';
import '../../plan/presentation/plan_controller.dart';
import 'currency_dialog.dart';
import 'friend_dialog.dart';
import 'settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.profile,
    required this.settings,
    required this.onReset,
    required this.onCurrencyChanged,
    required this.account,
    required this.plan,
  });

  final Profile profile;
  final SettingsController settings;
  final Future<void> Function() onReset;
  final Future<void> Function(String currency) onCurrencyChanged;
  final AccountController account;
  final PlanController plan;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LargeTitlePage(
      title: 'Настройки',
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              ListenableBuilder(
                listenable: settings,
                builder: (context, _) => AppSection(
                  header: 'Поддержка',
                  children: [
                    AppRow(
                      title: 'Напоминания',
                      subtitle:
                          'Утренняя мотивация, вечерний чек-ин и предупреждение '
                          'перед опасным временем',
                      trailing: CupertinoSwitch(
                        value: settings.notificationsEnabled,
                        activeTrackColor: c.positive,
                        onChanged: (v) async {
                          Haptics.selection();
                          final messenger = ScaffoldMessenger.of(context);
                          final ok = await settings.setNotificationsEnabled(v);
                          if (!ok) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Нет разрешения на уведомления. '
                                  'Разреши их в настройках системы.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    _FriendRow(settings: settings),
                  ],
                ),
              ),
              AppSection(
                header: 'План',
                children: [
                  AppRow(
                    title: 'Дата старта',
                    trailing: _Value(formatDate(profile.quitDate)),
                  ),
                  AppRow(
                    title: 'Способ',
                    trailing: _Value(
                      profile.quitMode == QuitMode.cold
                          ? 'Сразу'
                          : 'Постепенно',
                    ),
                  ),
                  AppRow(
                    title: 'Валюта',
                    trailing: _Value(
                      profile.currency.isEmpty ? 'Не задана' : profile.currency,
                      chevron: true,
                    ),
                    onTap: () async {
                      final cur = await showCurrencyDialog(
                        context,
                        profile.currency,
                      );
                      if (cur != null && cur != profile.currency) {
                        await onCurrencyChanged(cur);
                      }
                    },
                  ),
                ],
              ),
              ListenableBuilder(
                listenable: Listenable.merge([account, settings]),
                builder: (context, _) => AppSection(
                  header: 'Сообщество и ИИ',
                  footer:
                      'Сервер нужен для ленты, близких и ИИ-коуча. Подключение '
                      'анонимное: приложение получает случайный псевдоним.',
                  children: [
                    AppRow(
                      title: 'Сервер',
                      subtitle: account.connected
                          ? 'Подключён как ${account.account!.nick}'
                          : 'Не подключён',
                      trailing: const _Value('', chevron: true),
                      onTap: () => showServerDialog(context, account),
                    ),
                    if (account.connected)
                      AppRow(
                        title: 'Отключить и удалить мои данные',
                        subtitle:
                            'Посты, связи и сводка будут удалены с сервера',
                        destructive: true,
                        onTap: () async {
                          final ok = await confirmDestructive(
                            context,
                            title: 'Отключить сервер?',
                            message: 'Твои данные на сервере будут удалены.',
                            confirmLabel: 'Удалить',
                          );
                          if (ok) await account.deleteRemote();
                        },
                      ),
                    AppRow(
                      title: 'ИИ-коуч',
                      subtitle:
                          'Отправлять сообщения коучу на сервер для ответа',
                      trailing: CupertinoSwitch(
                        value: settings.coachAi == true,
                        activeTrackColor: c.positive,
                        onChanged: (v) {
                          Haptics.selection();
                          settings.setCoachAi(v);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (plan.paywall)
                ListenableBuilder(
                  listenable: plan,
                  builder: (context, _) => AppSection(
                    header: 'Подписка',
                    children: [
                      AppRow(
                        title: 'NoSmoke+',
                        subtitle: plan.isPremium
                            ? 'Активна'
                            : 'ИИ-коуч, итоги недели, виджеты',
                        trailing: const _Value('', chevron: true),
                        onTap: () => Navigator.of(context).push<void>(
                          CupertinoPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => PaywallScreen(plan: plan),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              AppSection(
                header: 'Данные',
                children: [
                  AppRow(
                    title: 'Начать заново',
                    subtitle: 'Удалит профиль, дневник и срывы',
                    destructive: true,
                    onTap: () async {
                      final ok = await confirmDestructive(
                        context,
                        title: 'Начать заново?',
                        message: 'Все данные будут удалены.',
                        confirmLabel: 'Удалить',
                      );
                      if (ok) await onReset();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final f = settings.friend;
    return AppRow(
      title: 'Друг для звонка в SOS',
      subtitle: f == null ? 'Не задан' : '${f.displayName} · ${f.phone}',
      trailing: f == null
          ? const _Value('', chevron: true)
          : CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () => settings.setFriend(null),
              child: Tooltip(
                message: 'Удалить контакт',
                child: Icon(
                  CupertinoIcons.trash,
                  size: 20,
                  color: context.colors.accent,
                ),
              ),
            ),
      onTap: () async {
        final friend = await showFriendDialog(context, initial: f);
        if (friend != null) await settings.setFriend(friend);
      },
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.text, {this.chevron = false});

  final String text;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (text.isNotEmpty)
          Text(text, style: context.type.body.copyWith(color: c.inkSecondary)),
        if (chevron) ...[
          const SizedBox(width: 6),
          Icon(CupertinoIcons.chevron_right, size: 14, color: c.inkTertiary),
        ],
      ],
    );
  }
}
