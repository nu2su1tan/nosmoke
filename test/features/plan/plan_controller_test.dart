import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/features/plan/domain/entitlements.dart';
import 'package:nosmoke/features/plan/presentation/plan_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late FakePurchaseService store;
  setUp(() => store = FakePurchaseService());

  test('paywall disabled: everything is available for free', () {
    final plan = PlanController(store, paywall: false);
    for (final f in PremiumFeature.values) {
      expect(plan.can(f), isTrue, reason: '$f');
    }
    plan.dispose();
  });

  test('paywall enabled: premium features are locked until purchase', () async {
    final plan = PlanController(store, paywall: true);
    await plan.load();
    for (final f in PremiumFeature.values) {
      expect(plan.can(f), isFalse, reason: '$f');
    }

    store.completePurchase();
    await Future<void>.delayed(Duration.zero);
    expect(plan.isPremium, isTrue);
    for (final f in PremiumFeature.values) {
      expect(plan.can(f), isTrue, reason: '$f');
    }
  });

  test('premium is remembered across launches and can be cleared', () async {
    final plan = PlanController(store, paywall: true);
    store.completePurchase();
    await Future<void>.delayed(Duration.zero);

    final next = PlanController(FakePurchaseService(), paywall: true);
    await next.load();
    expect(next.isPremium, isTrue);

    await next.clear();
    final after = PlanController(FakePurchaseService(), paywall: true);
    await after.load();
    expect(after.isPremium, isFalse);
    plan.dispose();
  });

  test('products load; buy and restore go to the store', () async {
    final plan = PlanController(store, paywall: true);
    await plan.loadProducts();
    expect(plan.products.map((p) => p.id), premiumProductIds);
    expect(plan.loading, isFalse);

    expect(await plan.buy('nosmoke_premium_yearly'), isTrue);
    await plan.restore();
    expect(store.bought, ['nosmoke_premium_yearly']);
    expect(store.restores, 1);
  });

  test('a free core is never gated', () {
    // SOS, счётчик, дневник, срывы, челленджи и напоминания не входят в подписку.
    expect(PremiumFeature.values.map((f) => f.name).toSet(), {
      'coachAi',
      'weeklyReport',
      'widgets',
      'healthMetrics',
    });
  });
}
