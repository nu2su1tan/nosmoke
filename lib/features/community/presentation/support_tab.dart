import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show ScaffoldMessenger, SnackBar, Tooltip;

import '../../../app/session.dart';
import '../../../core/ui/app_banner.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_chip.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_overlays.dart';
import '../../../core/ui/app_section.dart';
import '../../../core/ui/app_text_field.dart';
import '../../../core/ui/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/plural.dart';
import '../../supporters/domain/supporters_models.dart';
import '../domain/share_text.dart';
import '../domain/tips.dart';
import 'connect_prompt.dart';

/// Вкладка «Поддержка»: близкие, ободрения, поделиться прогрессом, советы.
class SupportTab extends StatefulWidget {
  const SupportTab({super.key, required this.session});

  final Session session;

  @override
  State<SupportTab> createState() => _SupportTabState();
}

class _SupportTabState extends State<SupportTab> {
  Session get s => widget.session;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) s.supporters.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return ListenableBuilder(
      listenable: Listenable.merge([s.supporters, s.account]),
      builder: (context, _) => Column(
        children: [
          _closeOnes(context),
          AppSection(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            header: 'Попроси поддержки',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Поделись прогрессом с друзьями и близкими. Их поддержка '
                      'помогает не сорваться.',
                      style: t.callout,
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Поделиться прогрессом',
                      icon: CupertinoIcons.share,
                      onPressed: () => s.services.sharer.shareText(
                        buildShareText(s.profile, s.progressNow()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSection(
            header: 'Советы',
            children: [
              for (var i = 0; i < supportTips.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(
                          two(i + 1),
                          style: t.label.copyWith(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(supportTips[i].title, style: t.bodyStrong),
                            const SizedBox(height: 4),
                            Text(supportTips[i].body, style: t.callout),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _closeOnes(BuildContext context) {
    if (!s.account.connected) {
      return ConnectPrompt(
        session: s,
        title: 'Близкие',
        body:
            'Пригласи близкого человека: он увидит твои дни без сигарет и '
            'сможет присылать ободрение. Или стань поддержкой для друга. '
            'Для этого нужен сервер.',
      );
    }
    final t = context.type;
    final c = context.colors;
    final now = DateTime.now();
    final sos = s.supporters.supporting
        .where((o) => o.sosRecently(now))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final o in sos)
          AppBanner(
            accent: true,
            title: '${o.nick} нажал(а) SOS ${formatAgo(o.lastSosAt!, now)}',
            body: 'Самое время написать пару тёплых слов.',
            onTap: () => _cheerSheet(context, o),
          ),
        AppSection(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          header: 'Мои близкие',
          footer:
              'Близкие видят только дни без сигарет и дни в программе. Деньги, '
              'срывы и дневник не передаются.',
          children: [
            if (s.supporters.supporters.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'Пока никого. Пригласи близкого по коду.',
                  style: t.callout,
                ),
              ),
            for (final p in s.supporters.supporters)
              AppRow(
                title: p.nick,
                subtitle: 'С ${formatDate(p.since)}',
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () => s.supporters.unlink(p.supporterId),
                  child: Tooltip(
                    message: 'Отключить ${p.nick}',
                    child: Icon(
                      CupertinoIcons.xmark_circle,
                      size: 22,
                      color: c.inkTertiary,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  key: const Key('invite-button'),
                  label: 'Пригласить близкого',
                  icon: CupertinoIcons.person_add,
                  style: AppButtonStyle.outlined,
                  compact: true,
                  expand: false,
                  onPressed: () => _invite(context),
                ),
              ),
            ),
          ],
        ),
        AppSection(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          header: 'Я поддерживаю',
          children: [
            for (final o in s.supporters.supporting)
              AppRow(
                title: o.nick,
                subtitle:
                    '${o.smokeFreeDays} ${daysWord(o.smokeFreeDays)} без сигарет · '
                    'в программе ${o.daysInProgram} ${daysWord(o.daysInProgram)}',
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () => _cheerSheet(context, o),
                  child: Text(
                    'Поддержать',
                    style: t.callout.copyWith(
                      color: c.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  key: const Key('enter-code-button'),
                  label: 'Ввести код друга',
                  style: AppButtonStyle.outlined,
                  compact: true,
                  expand: false,
                  onPressed: () => _enterCode(context),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _invite(BuildContext context) async {
    final (code, err) = await s.supporters.createInvite();
    if (!context.mounted) return;
    if (code == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(supportErrorText(err ?? ''))));
      return;
    }
    await showAppSheet<void>(
      context,
      builder: (_) => _InviteSheet(code: code, session: s),
    );
  }

  Future<void> _enterCode(BuildContext context) async {
    await showAppSheet<void>(context, builder: (_) => _CodeSheet(session: s));
  }

  Future<void> _cheerSheet(BuildContext context, SupportedOwner o) async {
    await showAppSheet<void>(
      context,
      builder: (_) => _CheerSheet(owner: o, session: s),
    );
  }
}

class _InviteSheet extends StatelessWidget {
  const _InviteSheet({required this.code, required this.session});

  final String code;
  final Session session;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetTitle(
            'Код приглашения',
            subtitle: 'Действует 7 дней и подходит одному человеку.',
          ),
          const SizedBox(height: 12),
          Text(
            code,
            key: const Key('invite-code'),
            style: t.display.copyWith(fontSize: 64, letterSpacing: 6),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Отправить код',
            icon: CupertinoIcons.share,
            onPressed: () => session.services.sharer.shareText(
              'Я бросаю курить и прошу тебя поддержать меня. '
              'Установи NoSmoke, открой «Сообщество → Поддержка → Ввести код '
              'друга» и введи код: $code',
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeSheet extends StatefulWidget {
  const _CodeSheet({required this.session});

  final Session session;

  @override
  State<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends State<_CodeSheet> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final (nick, err) = await widget.session.supporters.accept(_code.text);
    if (!mounted) return;
    if (nick != null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Теперь ты поддерживаешь: $nick')));
    } else {
      setState(() {
        _busy = false;
        _error = supportErrorText(err ?? '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetTitle(
            'Код друга',
            subtitle: 'Введи 6 символов из приглашения.',
          ),
          const SizedBox(height: 12),
          AppTextField(
            fieldKey: const Key('code-field'),
            controller: _code,
            placeholder: 'ABC123',
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            errorText: _error,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Подключиться',
            onPressed: _busy || _code.text.trim().length < 6 ? null : _accept,
          ),
        ],
      ),
    );
  }
}

class _CheerSheet extends StatefulWidget {
  const _CheerSheet({required this.owner, required this.session});

  final SupportedOwner owner;
  final Session session;

  @override
  State<_CheerSheet> createState() => _CheerSheetState();
}

class _CheerSheetState extends State<_CheerSheet> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final err = await widget.session.supporters.cheer(
      widget.owner.ownerId,
      text,
    );
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Сообщение отправлено')));
    } else {
      setState(() => _error = supportErrorText(err));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetTitle(
            'Поддержать: ${widget.owner.nick}',
            subtitle:
                '${widget.owner.smokeFreeDays} ${daysWord(widget.owner.smokeFreeDays)} без сигарет',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in cheerPresets)
                AppChip(label: p, selected: false, onTap: () => _send(p)),
            ],
          ),
          const SizedBox(height: 20),
          Text('ИЛИ НАПИШИ СВОЁ', style: t.label),
          const SizedBox(height: 8),
          AppTextField(
            fieldKey: const Key('cheer-text'),
            controller: _text,
            maxLength: 140,
            errorText: _error,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Отправить',
            onPressed: _text.text.trim().isEmpty
                ? null
                : () => _send(_text.text.trim()),
          ),
        ],
      ),
    );
  }
}
