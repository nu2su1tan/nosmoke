import 'package:flutter/cupertino.dart';

import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_section.dart';
import '../../../core/ui/app_type.dart';
import '../../../core/ui/large_title_page.dart';
import '../domain/entitlements.dart';
import 'plan_controller.dart';

/// Открывает экран подписки, если функция недоступна. Возвращает true,
/// когда доступ есть (сразу или после покупки).
Future<bool> requirePremium(
  BuildContext context,
  PlanController plan,
  PremiumFeature feature,
) async {
  if (plan.can(feature)) return true;
  await Navigator.of(context).push<void>(
    CupertinoPageRoute(
      fullscreenDialog: true,
      builder: (_) => PaywallScreen(plan: plan, feature: feature),
    ),
  );
  return plan.can(feature);
}

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, required this.plan, this.feature});

  final PlanController plan;
  final PremiumFeature? feature;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  @override
  void initState() {
    super.initState();
    widget.plan.addListener(_onPlan);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.plan.loadProducts();
    });
  }

  void _onPlan() {
    if (widget.plan.isPremium && mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    widget.plan.removeListener(_onPlan);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final plan = widget.plan;
    return ModalPage(
      title: 'NoSmoke+',
      child: ListenableBuilder(
        listenable: plan,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            Text('Больше поддержки, когда она нужна', style: t.title),
            const SizedBox(height: 12),
            Text(
              widget.feature == null
                  ? 'SOS, счётчик, дневник и напоминания остаются бесплатными '
                        'навсегда.'
                  : '«${widget.feature!.title}» входит в подписку. SOS, '
                        'счётчик, дневник и напоминания остаются бесплатными.',
              style: t.callout,
            ),
            AppSection(
              padding: const EdgeInsets.only(top: 28),
              header: 'Что входит',
              children: [
                for (final f in PremiumFeature.values)
                  AppRow(
                    title: f.title,
                    leading: Icon(
                      CupertinoIcons.checkmark_alt,
                      size: 20,
                      color: context.colors.ink,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            if (plan.loading)
              const Center(child: CupertinoActivityIndicator())
            else if (plan.products.isEmpty)
              Text(
                'Магазин сейчас недоступен. Попробуй позже.',
                style: t.callout,
              )
            else
              for (final p in plan.products) ...[
                AppButton(
                  label: '${p.title} · ${p.price}',
                  onPressed: () => plan.buy(p.id),
                ),
                const SizedBox(height: 8),
              ],
            AppButton(
              label: 'Восстановить покупки',
              style: AppButtonStyle.text,
              onPressed: plan.restore,
            ),
          ],
        ),
      ),
    );
  }
}
