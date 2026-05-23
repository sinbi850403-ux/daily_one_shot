import 'package:daily_one_shot/data/database.dart';
import 'package:daily_one_shot/data/entry_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late EntryRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = EntryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('dayKey collapses different times of same local day to same instant',
      () {
    final a = DateTime(2026, 5, 23, 1, 0);
    final b = DateTime(2026, 5, 23, 23, 30);
    expect(dayKey(a), equals(dayKey(b)));
  });

  test('upsert twice on same day updates instead of inserting', () async {
    final day = DateTime(2026, 5, 23);
    final id1 = await repo.upsert(day: day, photoPath: 'a.jpg', memo: '아침');
    final id2 = await repo.upsert(day: day, photoPath: 'b.jpg', memo: '저녁');
    expect(id1, equals(id2));
    final all = await repo.listAll();
    expect(all.length, 1);
    expect(all.first.photoPath, 'b.jpg');
    expect(all.first.memo, '저녁');
  });

  test('search finds memo by FTS prefix', () async {
    await repo.upsert(
        day: DateTime(2026, 5, 1), photoPath: 'a.jpg', memo: '제주도 여행 첫날');
    await repo.upsert(
        day: DateTime(2026, 5, 2), photoPath: 'b.jpg', memo: '카페에서 책 읽기');
    await repo.upsert(
        day: DateTime(2026, 5, 3), photoPath: 'c.jpg', memo: '집에서 쉬는 날');

    final cafe = await repo.search('카페');
    expect(cafe.length, 1);
    expect(cafe.first.memo, contains('카페'));

    final none = await repo.search('zzzzzz');
    expect(none, isEmpty);
  });

  test('onThisDayInPriorYears matches month+day in earlier years', () async {
    await repo.upsert(
        day: DateTime(2024, 5, 23), photoPath: 'a.jpg', memo: '작년 오늘');
    await repo.upsert(
        day: DateTime(2025, 5, 23), photoPath: 'b.jpg', memo: '재작년 오늘');
    await repo.upsert(
        day: DateTime(2024, 6, 1), photoPath: 'c.jpg', memo: '다른 날');

    final memories = await repo.onThisDayInPriorYears(DateTime(2026, 5, 23));
    expect(memories.length, 2);
    expect(memories.every((e) => e.date.month == 5 && e.date.day == 23), isTrue);
  });
}
