import 'package:http/http.dart' as http;

import '../core/services/phone_dialer.dart';
import '../core/services/share_service.dart';
import '../features/account/data/account_store.dart';
import '../features/account/presentation/account_controller.dart';
import '../features/challenges/data/challenge_store.dart';
import '../features/challenges/presentation/challenge_controller.dart';
import '../features/coach/data/coach_service.dart';
import '../features/coach/domain/coach_models.dart';
import '../features/coach/presentation/coach_controller.dart';
import '../features/diary/data/diary_store.dart';
import '../features/diary/presentation/diary_controller.dart';
import '../features/feed/data/feed_repository.dart';
import '../features/feed/presentation/feed_controller.dart';
import '../features/goals/data/goal_store.dart';
import '../features/goals/presentation/goal_controller.dart';
import '../features/health_data/data/health_source.dart';
import '../features/health_data/presentation/health_controller.dart';
import '../features/home_widget/data/widget_service.dart';
import '../features/notifications/data/notification_service.dart';
import '../features/notifications/data/reminder_scheduler.dart';
import '../features/plan/data/purchase_service.dart';
import '../features/plan/domain/entitlements.dart';
import '../features/plan/presentation/plan_controller.dart';
import '../features/profile/domain/profile.dart';
import '../features/progress/domain/progress.dart';
import '../features/relapse/data/relapse_store.dart';
import '../features/relapse/presentation/relapse_controller.dart';
import '../features/settings/data/settings_store.dart';
import '../features/settings/presentation/settings_controller.dart';
import '../features/smoked/data/smoked_store.dart';
import '../features/smoked/presentation/smoked_controller.dart';
import '../features/supporters/data/supporters_repository.dart';
import '../features/supporters/presentation/supporters_controller.dart';
import 'live_sync.dart';

/// Внешние сервисы приложения; в тестах подменяются заглушками.
class Services {
  Services({
    required this.notifications,
    this.dialer = const UrlLauncherDialer(),
    this.sharer = const SharePlusService(),
    PurchaseService? purchases,
    HealthSource? health,
    WidgetService? widgets,
    this.httpClient = http.Client.new,
    this.paywall = paywallEnabled,
  }) : purchases =
           purchases ??
           (paywall ? StorePurchaseService() : NoPurchaseService()),
       health = health ?? PlatformHealthSource(),
       widgets = widgets ?? HomeWidgetService();

  final NotificationService notifications;
  final PhoneDialer dialer;
  final ShareService sharer;
  final PurchaseService purchases;
  final HealthSource health;
  final WidgetService widgets;
  final http.Client Function() httpClient;

  /// Включена ли подписка (в тестах включается явно).
  final bool paywall;
}

/// Всё состояние, которое существует, пока профиль создан.
class Session {
  Session._({
    required this.profile,
    required this.diary,
    required this.relapses,
    required this.smoked,
    required this.goals,
    required this.settings,
    required this.challenges,
    required this.plan,
    required this.account,
    required this.feed,
    required this.supporters,
    required this.healthData,
    required this.scheduler,
    required this.liveSync,
    required this.services,
  });

  final Profile profile;
  final DiaryController diary;
  final RelapseController relapses;
  final SmokedController smoked;
  final GoalController goals;
  final SettingsController settings;
  final ChallengeController challenges;
  final PlanController plan;
  final AccountController account;
  final FeedController feed;
  final SupportersController supporters;
  final HealthController healthData;
  final ReminderScheduler scheduler;
  final LiveSync liveSync;
  final Services services;

  static Future<Session> start(Profile profile, Services services) async {
    final diary = DiaryController(diaryStore());
    final relapses = RelapseController(relapseStore());
    final smoked = SmokedController(smokedStore());
    final goals = GoalController(goalStore());
    final settings = SettingsController(
      SettingsStore(),
      services.notifications,
    );
    final plan = PlanController(services.purchases, paywall: services.paywall);
    final account = AccountController(
      AccountStore(),
      clientFactory: services.httpClient,
    );
    final healthData = HealthController(services.health);
    await Future.wait([
      diary.load(),
      relapses.load(),
      smoked.load(),
      goals.load(),
      settings.load(),
      plan.load(),
      account.load(),
      healthData.load(),
    ]);
    final challenges = ChallengeController(challengeStore(), diary, relapses);
    await challenges.load();

    final feed = FeedController(() {
      final api = account.api;
      return api == null ? null : RemoteFeedRepository(api);
    });
    final supporters = SupportersController(() {
      final api = account.api;
      return api == null ? null : RemoteSupportersRepository(api);
    });
    final scheduler = ReminderScheduler(
      profile: profile,
      diary: diary,
      settings: settings,
      relapses: relapses,
      smoked: smoked,
      service: services.notifications,
    );
    final liveSync = LiveSync(
      profile: profile,
      relapses: relapses,
      smoked: smoked,
      supporters: supporters,
      plan: plan,
      widgets: services.widgets,
    );
    await scheduler.refresh();
    // Сеть не должна задерживать запуск: синхронизация идёт фоном.
    liveSync.sync();
    return Session._(
      profile: profile,
      diary: diary,
      relapses: relapses,
      smoked: smoked,
      goals: goals,
      settings: settings,
      challenges: challenges,
      plan: plan,
      account: account,
      feed: feed,
      supporters: supporters,
      healthData: healthData,
      scheduler: scheduler,
      liveSync: liveSync,
      services: services,
    );
  }

  /// Снимок прогресса «сейчас» с учётом записей «выкурил(а) по плану».
  ProgressSnapshot progressNow([DateTime? now]) => computeProgress(
    profile,
    relapses.items,
    now ?? DateTime.now(),
    smoked: smoked.items,
  );

  /// Контекст для коуча.
  CoachContext coachContext() =>
      CoachContext.from(profile, progressNow(), diary.insights, DateTime.now());

  /// Новый чат с коучем: офлайн по умолчанию, ИИ — если пользователь
  /// разрешил и сервер подключён.
  CoachController newCoachChat() => CoachController(
    FallbackCoach(
      remote: () {
        final api = account.api;
        return api == null ? null : RemoteCoach(api);
      },
      aiAllowed: () =>
          settings.coachAi == true && plan.can(PremiumFeature.coachAi),
    ),
    coachContext,
  );

  /// Стирает все пользовательские данные, в том числе на сервере.
  Future<void> wipe() async {
    // Сначала отписываем фоновые обновления, иначе очистка данных заново
    // запланирует напоминания и отправит сводку.
    scheduler.dispose();
    liveSync.dispose();
    await account.deleteRemote();
    await const SeenMarker().clear();
    await diary.clear();
    await relapses.clear();
    await smoked.clear();
    await goals.clear();
    await challenges.clear();
    await healthData.clear();
    await plan.clear();
    await settings.clear();
    await services.notifications.cancelAll();
  }

  void dispose() {
    scheduler.dispose();
    liveSync.dispose();
    challenges.dispose();
    diary.dispose();
    relapses.dispose();
    smoked.dispose();
    goals.dispose();
    settings.dispose();
    plan.dispose();
    account.dispose();
    feed.dispose();
    supporters.dispose();
    healthData.dispose();
  }
}
