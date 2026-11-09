import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/session.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/haptics.dart';
import '../../community/presentation/community_screen.dart';
import '../../diary/presentation/diary_screen.dart';
import '../../health/presentation/health_screen.dart';
import '../../progress/presentation/progress_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../sos/presentation/sos_screen.dart';

/// Нативная нижняя панель: Главная, Дневник, Здоровье, Сообщество, Настройки.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.session,
    required this.onReset,
    required this.onCurrencyChanged,
  });

  final Session session;
  final Future<void> Function() onReset;
  final Future<void> Function(String currency) onCurrencyChanged;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  StreamSubscription<Uri?>? _widgetClicks;

  @override
  void initState() {
    super.initState();
    final w = widget.session.services.widgets;
    _widgetClicks = w.clicks.listen(_onWidgetUri);
    // Приложение могло быть запущено нажатием на виджет.
    w.launchUri().then(_onWidgetUri);
  }

  @override
  void dispose() {
    _widgetClicks?.cancel();
    super.dispose();
  }

  /// nosmoke://sos из виджета открывает экран SOS.
  void _onWidgetUri(Uri? uri) {
    if (uri == null || !mounted) return;
    if (uri.host == 'sos') {
      setState(() => _index = 0);
      openSos(context, session: widget.session);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: IndexedStack(
        index: _index,
        children: [
          ProgressScreen(session: s),
          DiaryScreen(diary: s.diary),
          HealthScreen(session: s),
          CommunityScreen(session: s),
          SettingsScreen(
            profile: s.profile,
            settings: s.settings,
            onReset: widget.onReset,
            onCurrencyChanged: widget.onCurrencyChanged,
            account: s.account,
            plan: s.plan,
          ),
        ],
      ),
      bottomNavigationBar: CupertinoTabBar(
        currentIndex: _index,
        backgroundColor: c.bg.withValues(alpha: 0.92),
        activeColor: c.ink,
        inactiveColor: c.inkTertiary,
        border: Border(top: BorderSide(color: c.hairline, width: 0.5)),
        onTap: (i) {
          if (i != _index) Haptics.selection();
          setState(() => _index = i);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house),
            activeIcon: Icon(CupertinoIcons.house_fill),
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.book),
            activeIcon: Icon(CupertinoIcons.book_fill),
            label: 'Дневник',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.heart),
            activeIcon: Icon(CupertinoIcons.heart_fill),
            label: 'Здоровье',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_2),
            activeIcon: Icon(CupertinoIcons.person_2_fill),
            label: 'Сообщество',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.gear),
            activeIcon: Icon(CupertinoIcons.gear_solid),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }
}
