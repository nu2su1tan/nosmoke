import 'package:flutter/cupertino.dart';

import '../../../app/session.dart';
import '../../../core/ui/app_segmented.dart';
import '../../../core/ui/large_title_page.dart';
import '../../challenges/presentation/challenges_screen.dart';
import 'feed_tab.dart';
import 'support_tab.dart';

/// Три раздела: челленджи, лента сообщества и поддержка близких.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key, required this.session});

  final Session session;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return LargeTitlePage(
      title: 'Сообщество',
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: AppSegmented(
              labels: const ['Челленджи', 'Лента', 'Поддержка'],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: switch (_tab) {
            0 => ChallengesList(controller: s.challenges),
            1 => FeedTab(session: s),
            _ => SupportTab(session: s),
          },
        ),
      ],
    );
  }
}
