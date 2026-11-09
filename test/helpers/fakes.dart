import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nosmoke/app/session.dart';
import 'package:nosmoke/features/health_data/data/health_source.dart';
import 'package:nosmoke/features/health_data/domain/health_metrics.dart';
import 'package:nosmoke/features/home_widget/data/widget_service.dart';
import 'package:nosmoke/features/home_widget/domain/widget_snapshot.dart';
import 'package:nosmoke/features/plan/data/purchase_service.dart';
import 'package:nosmoke/features/plan/domain/entitlements.dart';
import 'package:nosmoke/core/services/phone_dialer.dart';
import 'package:nosmoke/core/services/share_service.dart';
import 'package:nosmoke/features/notifications/data/notification_service.dart';
import 'package:nosmoke/features/notifications/domain/reminder.dart';
import 'package:nosmoke/features/profile/domain/profile.dart';

class FakeNotificationService implements NotificationService {
  FakeNotificationService({this.grant = true, this.throwOnSchedule = false});

  bool grant;
  bool throwOnSchedule;

  /// Порядок вызовов: 'schedule' / 'cancel'.
  final List<String> events = [];
  int permissionRequests = 0;
  int cancelAllCalls = 0;
  final List<List<Reminder>> scheduled = [];

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grant;
  }

  @override
  Future<void> schedule(List<Reminder> reminders) async {
    if (throwOnSchedule) throw StateError('schedule failed');
    events.add('schedule');
    scheduled.add(reminders);
  }

  @override
  Future<void> cancelAll() async {
    events.add('cancel');
    cancelAllCalls++;
  }
}

class FakeDialer implements PhoneDialer {
  FakeDialer({this.succeed = true});

  bool succeed;
  final List<String> calls = [];

  @override
  Future<bool> call(String phone) async {
    calls.add(phone);
    return succeed;
  }
}

class FakeSharer implements ShareService {
  final List<String> shared = [];

  @override
  Future<void> shareText(String text) async => shared.add(text);
}

class FakeWidgetService implements WidgetService {
  final List<WidgetSnapshot> updates = [];
  final StreamController<Uri?> clickController =
      StreamController<Uri?>.broadcast();
  Uri? launch;

  @override
  Future<void> update(WidgetSnapshot s) async => updates.add(s);

  @override
  Stream<Uri?> get clicks => clickController.stream;

  @override
  Future<Uri?> launchUri() async => launch;
}

class FakeHealthSource implements HealthSource {
  FakeHealthSource({this.access = HealthAccess.granted, this.days = const []});

  HealthAccess access;
  List<DailyHealth> days;
  int connectCalls = 0;

  @override
  Future<HealthAccess> connect() async {
    connectCalls++;
    return access;
  }

  @override
  Future<List<DailyHealth>> daily(DateTime from, DateTime to) async => days;
}

class FakePurchaseService implements PurchaseService {
  final StreamController<bool> _premium = StreamController<bool>.broadcast();
  final List<String> bought = [];
  int restores = 0;
  List<PremiumProduct> available = const [
    PremiumProduct(
      id: 'nosmoke_premium_monthly',
      title: 'Месяц',
      price: '299 ₸',
    ),
    PremiumProduct(id: 'nosmoke_premium_yearly', title: 'Год', price: '1990 ₸'),
  ];

  /// Имитирует успешную покупку.
  void completePurchase() => _premium.add(true);

  @override
  Stream<bool> get premiumChanges => _premium.stream;

  @override
  Future<List<PremiumProduct>> products() async => available;

  @override
  Future<bool> buy(String productId) async {
    bought.add(productId);
    return true;
  }

  @override
  Future<void> restore() async => restores++;

  @override
  void dispose() => _premium.close();
}

/// HTTP-клиент, который никуда не ходит: любой запрос — «нет связи».
http.Client offlineClient() =>
    MockClient((_) async => throw http.ClientException('offline'));

Services makeServices({
  FakeNotificationService? notifications,
  FakeDialer? dialer,
  FakeSharer? sharer,
  FakePurchaseService? purchases,
  FakeHealthSource? health,
  FakeWidgetService? widgets,
  http.Client Function()? httpClient,
  bool paywall = false,
}) => Services(
  notifications: notifications ?? FakeNotificationService(),
  dialer: dialer ?? FakeDialer(),
  sharer: sharer ?? FakeSharer(),
  purchases: purchases ?? FakePurchaseService(),
  health: health ?? FakeHealthSource(),
  widgets: widgets ?? FakeWidgetService(),
  httpClient: httpClient ?? offlineClient,
  paywall: paywall,
);

Profile makeProfile({
  int cigs = 20,
  QuitMode mode = QuitMode.cold,
  int years = 5,
  DateTime? quitDate,
  String motivationText = 'дочь',
  Set<Trigger> triggers = const {Trigger.coffee},
  String currency = '₸',
}) => Profile(
  cigsPerDay: cigs,
  packPrice: 2000,
  cigsPerPack: 20,
  yearsSmoking: years,
  triggers: triggers,
  motivations: const {Motivation.health},
  motivationText: motivationText,
  quitMode: mode,
  quitDate: quitDate ?? DateTime(2026, 1, 1),
  currency: currency,
);
