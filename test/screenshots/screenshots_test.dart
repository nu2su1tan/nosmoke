// Снимает скриншоты экранов в светлой и тёмной теме.
// Запуск: SHOTS_DIR=/путь flutter test test/screenshots/screenshots_test.dart
// Без SHOTS_DIR ничего не делает. Нужен macOS (берёт системный Arial).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/app/app.dart';
import 'package:nosmoke/features/diary/domain/craving_entry.dart';
import 'package:nosmoke/features/profile/domain/profile.dart';
import 'package:nosmoke/features/relapse/domain/relapse.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

Future<void> _loadFonts() async {
  const base = '/System/Library/Fonts/Supplemental';
  Future<ByteData> bytes(String f) async =>
      ByteData.sublistView(await File('$base/$f').readAsBytes());
  final regular = await bytes('Arial.ttf');
  final bold = await bytes('Arial Bold.ttf');
  // Иконки Cupertino (в тестах шрифты пакетов сами не подгружаются).
  final icons = ByteData.sublistView(
    await File(
      '/Users/nursultan/.pub-cache/hosted/pub.dev/cupertino_icons-1.0.9/assets/CupertinoIcons.ttf',
    ).readAsBytes(),
  );
  await (FontLoader(
    'packages/cupertino_icons/CupertinoIcons',
  )..addFont(Future.value(icons))).load();
  for (final family in [
    'Ahem', // шрифт по умолчанию в тестах, если у стиля не задано семейство
    'Roboto',
    '.SF Pro Text',
    '.SF Pro Display',
    '.SF UI Text',
    '.SF UI Display',
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
  ]) {
    final l = FontLoader(family)
      ..addFont(Future.value(regular))
      ..addFont(Future.value(bold));
    await l.load();
  }
}

void main() {
  final dir = Platform.environment['SHOTS_DIR'];

  testWidgets('screenshots', skip: dir == null, (tester) async {
    await tester.runAsync(_loadFonts);
    Directory(dir!).createSync(recursive: true);
    // Высокий экран, чтобы на снимке главной помещались все блоки.
    tester.view.physicalSize = const Size(390 * 3, 1500 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    final key = GlobalKey();
    var n = 0;
    Future<void> shot(String name) async {
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$dir/${(++n).toString().padLeft(2, '0')}_$name.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
      });
    }

    Future<void> tab(String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(CupertinoTabBar),
          matching: find.text(label),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }

    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;

      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day - 12);
      final profile = makeProfile(
        currency: 'сом',
        quitDate: start,
        motivationText: 'Хочу играть с дочерью и бегать по утрам',
      );
      SharedPreferences.setMockInitialValues({
        'profile_v1': profile.encode(),
        'friend_name_v1': 'Айдос',
        'friend_phone_v1': '+77771234567',
        'relapses_v1': jsonEncode([
          Relapse(
            at: DateTime(now.year, now.month, now.day - 5, 22),
            count: 2,
          ).toJson(),
        ]),
        'diary_v1': jsonEncode([
          for (var i = 0; i < 5; i++)
            CravingEntry(
              id: 'e$i',
              at: DateTime(now.year, now.month, now.day - i, 9 + i),
              trigger: Trigger.values[i % 4],
              intensity: 2 + i % 3,
              overcame: i != 2,
              note: i == 1 ? 'Стресс на работе' : '',
            ).toJson(),
        ]),
      });

      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: NoSmokeApp(services: makeServices()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      await shot('${mode}_home');
      await tester.ensureVisible(find.text('Поговорить с коучем'));
      await tester.tap(find.text('Поговорить с коучем'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Тянет курить прямо сейчас'));
      await shot('${mode}_coach');
      await tester.tap(find.text('Закрыть'));
      await tester.pump(const Duration(milliseconds: 500));
      await tab('Дневник');
      await shot('${mode}_diary');
      await tab('Здоровье');
      await shot('${mode}_health');
      await tester.tap(find.text('Достижения'));
      await shot('${mode}_achievements');
      await tab('Сообщество');
      await shot('${mode}_community');
      await tab('Настройки');
      await shot('${mode}_settings');
      await tab('Главная');
      await tester.tap(find.text('Хочу курить'));
      await shot('${mode}_sos');
      await tester.pumpWidget(const SizedBox());

      // Онбординг
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: NoSmokeApp(services: makeServices()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await shot('${mode}_onboarding_welcome');
      await tester.tap(find.text('Начать'));
      await tester.pump(const Duration(milliseconds: 400));
      await shot('${mode}_onboarding_cigs');
      await tester.tap(find.text('Дальше'));
      await tester.pump(const Duration(milliseconds: 400));
      await shot('${mode}_onboarding_price');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
