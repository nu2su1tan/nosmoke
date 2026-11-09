import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/app_theme.dart';
import '../core/ui/app_button.dart';
import '../core/ui/app_type.dart';
import '../features/home/presentation/home_shell.dart';
import '../features/notifications/data/notification_service.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/profile/data/profile_store.dart';
import '../features/profile/domain/profile.dart';
import 'session.dart';

class NoSmokeApp extends StatefulWidget {
  const NoSmokeApp({super.key, this.store, this.services});

  final ProfileStore? store;
  final Services? services;

  @override
  State<NoSmokeApp> createState() => _NoSmokeAppState();
}

class _NoSmokeAppState extends State<NoSmokeApp> {
  late final ProfileStore _store = widget.store ?? ProfileStore();
  late final Services _services =
      widget.services ?? Services(notifications: LocalNotificationService());
  Session? _session;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final profile = await _store.load();
      final session = profile == null
          ? null
          : await Session.start(profile, _services);
      if (!mounted) return;
      setState(() {
        _session = session;
        _loading = false;
        _failed = false;
      });
    } catch (e) {
      debugPrint('Startup failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    _bootstrap();
  }

  Future<void> _onboardingDone(Profile p) async {
    await _store.save(p);
    final session = await Session.start(p, _services);
    if (!mounted) return;
    setState(() => _session = session);
  }

  /// Меняет валюту: сохраняет профиль и пересоздаёт сессию с новым профилем.
  Future<void> _changeCurrency(String currency) async {
    final old = _session;
    if (old == null) return;
    final updated = old.profile.copyWith(currency: currency);
    await _store.save(updated);
    final session = await Session.start(updated, _services);
    if (!mounted) return;
    setState(() => _session = session);
    _disposeLater(old);
  }

  Future<void> _reset() async {
    final old = _session;
    await old?.wipe();
    await _store.clear();
    if (!mounted) return;
    setState(() => _session = null);
    if (old != null) _disposeLater(old);
  }

  /// Освобождаем контроллеры после перестройки дерева, чтобы виджеты успели
  /// от них отписаться.
  void _disposeLater(Session s) {
    WidgetsBinding.instance.addPostFrameCallback((_) => s.dispose());
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return MaterialApp(
      title: 'NoSmoke',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: _loading
          ? const Scaffold(body: Center(child: CupertinoActivityIndicator()))
          : _failed
          ? _StartupError(onRetry: _retry)
          : session == null
          ? OnboardingScreen(onDone: _onboardingDone)
          : HomeShell(
              session: session,
              onReset: _reset,
              onCurrencyChanged: _changeCurrency,
            ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Не удалось\nзагрузить данные', style: t.title),
              const SizedBox(height: 12),
              Text('Твой прогресс не потерян.', style: t.callout),
              const SizedBox(height: 32),
              AppButton(label: 'Повторить', onPressed: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}
