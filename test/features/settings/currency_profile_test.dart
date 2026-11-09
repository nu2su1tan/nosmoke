import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/features/profile/domain/profile.dart';

import '../../helpers/fakes.dart';

void main() {
  test('currency survives json roundtrip', () {
    final p = Profile.decode(makeProfile(currency: 'сом').encode());
    expect(p.currency, 'сом');
    expect(p.money(1500), '1500 сом');
  });

  test('old profiles without currency still load', () {
    final json = makeProfile().toJson()..remove('currency');
    final p = Profile.fromJson(json);
    expect(p.currency, '');
    expect(p.money(1500), '1500');
  });

  test('copyWith changes only the currency', () {
    final p = makeProfile(currency: '₸');
    final q = p.copyWith(currency: '₽');
    expect(q.currency, '₽');
    expect(q.cigsPerDay, p.cigsPerDay);
    expect(q.quitDate, p.quitDate);
    expect(q.motivationText, p.motivationText);
  });
}
