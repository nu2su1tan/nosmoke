/// Платная подписка включается только при сборке с флагом:
/// flutter build ... --dart-define=PAYWALL=true
/// Пока магазины не настроены, всё доступно бесплатно.
const paywallEnabled = bool.fromEnvironment('PAYWALL');

/// Что входит в подписку. SOS, счётчик, дневник, срывы, челленджи и
/// напоминания всегда бесплатны.
enum PremiumFeature {
  coachAi('ИИ-коуч'),
  weeklyReport('Итоги недели'),
  widgets('Виджеты'),
  healthMetrics('Показатели здоровья');

  const PremiumFeature(this.title);
  final String title;
}

class PremiumProduct {
  const PremiumProduct({
    required this.id,
    required this.title,
    required this.price,
  });

  final String id;
  final String title;
  final String price;
}

const premiumProductIds = {'nosmoke_premium_monthly', 'nosmoke_premium_yearly'};
