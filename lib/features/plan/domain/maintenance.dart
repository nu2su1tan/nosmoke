import '../../progress/domain/progress.dart';

/// Когда приложение переключается из «борьбы» в «закрепление результата».
const maintenanceAfter = Duration(days: 90);

bool isMaintenance(ProgressSnapshot s) =>
    s.streakActive && s.smokeFree >= maintenanceAfter;

class MaintenanceTip {
  const MaintenanceTip(this.title, this.body);

  final String title;
  final String body;
}

const maintenanceTips = <MaintenanceTip>[
  MaintenanceTip(
    'Стресс — главный риск',
    'Через 3 месяца срывы чаще всего случаются из-за стресса. '
        'Заведи 2–3 безопасных способа разгрузки: прогулка, дыхание, звонок.',
  ),
  MaintenanceTip(
    'Не «одну для вкуса»',
    'Одна сигарета почти всегда возвращает привычку. '
        'Решение «я не курю» проще, чем решение «сколько можно».',
  ),
  MaintenanceTip(
    'Держи вехи здоровья на виду',
    'Открывай раздел «Здоровье» раз в неделю: видимый прогресс '
        'поддерживает мотивацию лучше, чем сила воли.',
  ),
  MaintenanceTip(
    'Двигайся',
    'Регулярная активность снижает тягу и помогает не набрать вес, '
        'частую причину возвращения к курению.',
  ),
];
