import 'package:flutter/cupertino.dart';

import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_progress_bar.dart';
import '../../../core/ui/app_section.dart';
import '../../../core/ui/app_type.dart';
import '../../../core/widgets/tick_builder.dart';
import '../domain/challenge.dart';
import 'challenge_controller.dart';

/// Список челленджей (без собственной прокрутки: живёт внутри страницы).
class ChallengesList extends StatelessWidget {
  const ChallengesList({super.key, required this.controller});

  final ChallengeController controller;

  @override
  Widget build(BuildContext context) {
    return TickBuilder(
      interval: const Duration(seconds: 30),
      builder: (context, now) {
        // Прогресс по дням меняется со временем: проверяем цели вне build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.evaluate(now);
        });
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) => AppSection(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            header: 'Вызовы',
            children: [
              for (final def in challengeDefs)
                _ChallengeRow(def: def, controller: controller, now: now),
            ],
          ),
        );
      },
    );
  }
}

class _ChallengeRow extends StatelessWidget {
  const _ChallengeRow({
    required this.def,
    required this.controller,
    required this.now,
  });

  final ChallengeDef def;
  final ChallengeController controller;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final c = context.colors;
    final joined = controller.joinedFor(def.id);
    final done = joined?.completedAt != null;
    final progress = controller.progressOf(def, now);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${def.goal}', style: t.numeral),
                const SizedBox(height: 4),
                Text(def.unit, style: t.label),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(def.title, style: t.bodyStrong)),
                    if (done)
                      Icon(CupertinoIcons.rosette, size: 20, color: c.ink),
                  ],
                ),
                const SizedBox(height: 2),
                Text(def.description, style: t.callout),
                if (joined != null) ...[
                  const SizedBox(height: 12),
                  AppProgressBar(
                    value: progress / def.goal,
                    color: done ? c.positive : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    done
                        ? 'Выполнено!'
                        : '$progress из ${def.goal} ${def.unit}',
                    style: t.caption,
                  ),
                ],
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: joined == null
                      ? AppButton(
                          label: 'Принять вызов',
                          style: AppButtonStyle.outlined,
                          expand: false,
                          compact: true,
                          onPressed: () => controller.join(def.id),
                        )
                      : done
                      ? AppButton(
                          label: 'Начать заново',
                          style: AppButtonStyle.text,
                          expand: false,
                          compact: true,
                          onPressed: () => controller.join(def.id),
                        )
                      : AppButton(
                          label: 'Выйти',
                          style: AppButtonStyle.text,
                          expand: false,
                          compact: true,
                          onPressed: () => controller.leave(def.id),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
