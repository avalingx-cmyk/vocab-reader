import 'package:bookbeam/models/user_level.dart';
import 'package:bookbeam/models/word.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps legacy saved user levels into the new three-level model', () {
    expect(UserLevel.fromString('upperIntermediate'), UserLevel.intermediate);
    expect(UserLevel.fromString('advanced'), UserLevel.pro);
  });

  test('copyWith can clear nullable word fields explicitly', () {
    final word = Word(
      id: 'word-1',
      text: 'ephemeral',
      bookId: 'book-1',
      bookName: 'Meditations',
      pageNumber: 42,
      context: 'An ephemeral moment.',
      userLevel: UserLevel.beginner,
      summary: WordSummary(
        definition: 'Short-lived',
        mainSay: 'It does not last long.',
        useCases: const ['The beauty was ephemeral.'],
        similarWords: const ['brief'],
        detailedSummary: 'A short-lived thing.',
        generatedAt: DateTime(2026, 1, 1),
      ),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
      isPending: false,
      lastReviewedAt: DateTime(2026, 1, 3),
      nextReviewAt: DateTime(2026, 1, 4),
      successCount: 2,
      failureCount: 1,
    );

    final cleared = word.copyWith(
      bookId: null,
      pageNumber: null,
      context: null,
      summary: null,
      lastReviewedAt: null,
      nextReviewAt: null,
    );

    expect(cleared.bookId, isNull);
    expect(cleared.pageNumber, isNull);
    expect(cleared.context, isNull);
    expect(cleared.summary, isNull);
    expect(cleared.lastReviewedAt, isNull);
    expect(cleared.nextReviewAt, isNull);
  });
}
