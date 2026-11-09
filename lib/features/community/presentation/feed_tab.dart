import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Tooltip;

import '../../../app/session.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_overlays.dart';
import '../../../core/ui/app_section.dart';
import '../../../core/ui/app_text_field.dart';
import '../../../core/ui/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../feed/domain/feed_models.dart';
import '../../feed/presentation/feed_controller.dart';
import 'connect_prompt.dart';

class FeedTab extends StatefulWidget {
  const FeedTab({super.key, required this.session});

  final Session session;

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  FeedController get feed => widget.session.feed;

  @override
  void initState() {
    super.initState();
    // Не во время построения: контроллер сразу уведомляет слушателей.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) feed.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return ListenableBuilder(
      listenable: Listenable.merge([feed, s.account]),
      builder: (context, _) {
        if (!s.account.connected) {
          return ConnectPrompt(
            session: s,
            title: 'Лента сообщества',
            body:
                'Здесь люди анонимно делятся успехами и поддерживают друг '
                'друга. Лента работает через сервер: подключи его, и она '
                'появится.',
          );
        }
        final t = context.type;
        final c = context.colors;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ты: ${s.account.account!.nick}',
                      style: t.label,
                    ),
                  ),
                  AppButton(
                    key: const Key('feed-compose'),
                    label: 'Написать',
                    compact: true,
                    expand: false,
                    onPressed: () => _compose(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'Анонимно. Без ссылок и оскорблений. Нарушения можно скрыть '
                'жалобой.',
                style: t.caption,
              ),
            ),
            if (feed.loading && feed.posts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(child: CupertinoActivityIndicator()),
              )
            else if (feed.error != null && feed.posts.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(feedErrorText(feed.error!), style: t.callout),
                    const SizedBox(height: 8),
                    AppButton(
                      label: 'Повторить',
                      style: AppButtonStyle.outlined,
                      compact: true,
                      expand: false,
                      onPressed: feed.refresh,
                    ),
                  ],
                ),
              )
            else if (feed.posts.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Text(
                  'Пока тихо. Напиши первым: поделись, как проходит твой день.',
                  style: t.callout,
                ),
              )
            else
              AppSection(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                header: 'Лента',
                children: [
                  for (final p in feed.posts)
                    _PostRow(key: ValueKey(p.id), post: p, feed: feed, c: c),
                ],
              ),
          ],
        );
      },
    );
  }

  Future<void> _compose(BuildContext context) async {
    await showAppSheet<void>(
      context,
      builder: (_) => _ComposeSheet(feed: feed),
    );
  }
}

class _PostRow extends StatelessWidget {
  const _PostRow({
    super.key,
    required this.post,
    required this.feed,
    required this.c,
  });

  final FeedPost post;
  final FeedController feed;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${post.nick} · ${formatAgo(post.at, DateTime.now())}',
                  style: t.label.copyWith(fontSize: 10),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () => _menu(context),
                child: Tooltip(
                  message: 'Действия с постом',
                  child: Icon(
                    CupertinoIcons.ellipsis,
                    size: 20,
                    color: c.inkTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(post.text, style: t.body),
          const SizedBox(height: 12),
          Row(
            children: [
              CupertinoButton(
                key: Key('like-${post.id}'),
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () => feed.toggleLike(post.id),
                child: Row(
                  children: [
                    Icon(
                      post.liked
                          ? CupertinoIcons.heart_fill
                          : CupertinoIcons.heart,
                      size: 20,
                      color: post.liked ? c.accent : c.inkSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text('${post.likes}', style: t.callout),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              CupertinoButton(
                key: Key('comments-${post.id}'),
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () => showAppSheet<void>(
                  context,
                  builder: (_) => _CommentsSheet(post: post, feed: feed),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.chat_bubble,
                      size: 20,
                      color: c.inkSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text('${post.comments}', style: t.callout),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _menu(BuildContext context) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          if (post.mine)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                feed.remove(post.id);
              },
              child: const Text('Удалить'),
            )
          else
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                feed.report(post.id);
              },
              child: const Text('Пожаловаться'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Отмена'),
        ),
      ),
    );
  }
}

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet({required this.feed});

  final FeedController feed;

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final _text = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.feed.publish(_text.text.trim());
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _busy = false;
        _error = feedErrorText(err);
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
            'Новая запись',
            subtitle: 'Её увидят все. Не пиши личные данные.',
          ),
          const SizedBox(height: 12),
          AppTextField(
            fieldKey: const Key('compose-text'),
            controller: _text,
            placeholder: 'Как проходит твой день без сигарет?',
            maxLines: 4,
            maxLength: 500,
            errorText: _error,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Опубликовать',
            onPressed: _busy || _text.text.trim().isEmpty ? null : _publish,
          ),
        ],
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.post, required this.feed});

  final FeedPost post;
  final FeedController feed;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  List<FeedComment>? _comments;
  final _text = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await widget.feed.comments(widget.post.id);
    if (mounted) setState(() => _comments = list);
  }

  Future<void> _send() async {
    final err = await widget.feed.addComment(widget.post.id, _text.text.trim());
    if (!mounted) return;
    if (err == null) {
      _text.clear();
      setState(() => _error = null);
      await _load();
    } else {
      setState(() => _error = feedErrorText(err));
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
          const SheetTitle('Комментарии'),
          if (_comments == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (_comments!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Пока нет комментариев.', style: t.callout),
            )
          else
            for (final c in _comments!)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${c.nick} · ${formatAgo(c.at, DateTime.now())}',
                      style: t.label.copyWith(fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Text(c.text, style: t.body),
                  ],
                ),
              ),
          const SizedBox(height: 12),
          AppTextField(
            fieldKey: const Key('comment-text'),
            controller: _text,
            placeholder: 'Напиши поддерживающее слово',
            maxLength: 300,
            errorText: _error,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Отправить',
            onPressed: _text.text.trim().isEmpty ? null : _send,
          ),
        ],
      ),
    );
  }
}
