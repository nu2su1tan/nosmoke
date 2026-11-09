import 'package:flutter/cupertino.dart';

import '../../../app/session.dart';
import '../../../core/ui/app_banner.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_chip.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_type.dart';
import '../../../core/ui/haptics.dart';
import '../../../core/ui/large_title_page.dart';
import '../domain/coach_models.dart';
import 'coach_controller.dart';

Future<void> openCoach(BuildContext context, Session session) =>
    Navigator.of(context).push<void>(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => CoachScreen(session: session),
      ),
    );

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key, required this.session});

  final Session session;

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  late final CoachController _chat = widget.session.newCoachChat();
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _chat.addListener(_scrollDown);
  }

  @override
  void dispose() {
    _chat.removeListener(_scrollDown);
    _chat.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    Haptics.light();
    _input.clear();
    _chat.send(text);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final c = context.colors;
    final t = context.type;
    return ModalPage(
      title: 'Коуч',
      child: Column(
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([s.settings, s.account]),
            builder: (context, _) => _Mode(session: s),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _chat,
              builder: (context, _) {
                final msgs = _chat.messages;
                if (msgs.isEmpty) return _Intro(onPick: _send);
                return ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: [
                    for (final m in msgs) _Bubble(message: m),
                    if (_chat.sending)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: CupertinoActivityIndicator(),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.hairline, width: 0.5)),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                8,
                10 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      key: const Key('coach-input'),
                      controller: _input,
                      placeholder: 'Напиши, что происходит',
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 500,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      style: t.body,
                      placeholderStyle: t.body.copyWith(color: c.inkTertiary),
                      decoration: BoxDecoration(
                        color: c.fill,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  CupertinoButton(
                    key: const Key('coach-send'),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onPressed: () => _send(_input.text),
                    child: Icon(
                      CupertinoIcons.arrow_up_circle_fill,
                      size: 34,
                      color: c.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Режим коуча и запрос согласия на ИИ.
class _Mode extends StatelessWidget {
  const _Mode({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final t = context.type;
    final ai = s.settings.coachAi;
    if (!s.account.connected) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Офлайн-подсказки. Подключи сервер в Настройках, чтобы отвечал ИИ.',
            style: t.caption,
          ),
        ),
      );
    }
    if (ai == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBanner(
            title: 'Отвечать с помощью ИИ?',
            body:
                'Твои сообщения и краткая сводка (дни без сигарет, триггеры, '
                'причина; без имени и контактов) уйдут на сервер и в Anthropic '
                'для ответа. Это не медицинская консультация.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                AppButton(
                  key: const Key('coach-ai-yes'),
                  label: 'Разрешить',
                  compact: true,
                  expand: false,
                  onPressed: () => s.settings.setCoachAi(true),
                ),
                const SizedBox(width: 8),
                AppButton(
                  key: const Key('coach-ai-no'),
                  label: 'Только офлайн',
                  style: AppButtonStyle.text,
                  compact: true,
                  expand: false,
                  onPressed: () => s.settings.setCoachAi(false),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          ai
              ? 'Отвечает ИИ-коуч. Это не врач.'
              : 'Офлайн-подсказки. ИИ выключен.',
          style: t.caption,
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      children: [
        Text('Что сейчас происходит?', style: t.title.copyWith(fontSize: 28)),
        const SizedBox(height: 10),
        Text('Выбери подсказку или напиши своими словами.', style: t.callout),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in coachQuickPrompts)
              AppChip(label: p, selected: false, onTap: () => onPick(p)),
          ],
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final CoachMessage message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final mine = message.role == CoachRole.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: ShapeDecoration(
                color: mine ? c.ink : c.fill,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                message.text,
                style: t.body.copyWith(color: mine ? c.bg : c.ink),
              ),
            ),
          ),
          if (!mine)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                (message.source == CoachSource.remote
                    ? 'ИИ-коуч'
                    : 'Подсказка'),
                style: t.label.copyWith(fontSize: 9),
              ),
            ),
        ],
      ),
    );
  }
}
