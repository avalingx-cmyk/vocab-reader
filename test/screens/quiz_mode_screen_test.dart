import 'package:bookbeam/game/quiz_engine.dart';
import 'package:bookbeam/models/user_level.dart';
import 'package:bookbeam/models/word.dart';
import 'package:bookbeam/providers/quiz_provider.dart';
import 'package:bookbeam/providers/settings_provider.dart';
import 'package:bookbeam/screens/quiz_mode_screen.dart';
import 'package:bookbeam/services/adaptive_quiz_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows generating state before quiz session is ready',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quizProvider.overrideWith((ref) => _FakeQuizNotifier(
                const QuizState(isGenerating: true),
              )),
        ],
        child: const MaterialApp(
          home: QuizModeScreen(mode: QuizMode.multipleChoice),
        ),
      ),
    );

    expect(find.text('Generating quiz...'), findsOneWidget);
  });

  testWidgets('shows fallback notice when using standard quiz',
      (tester) async {
    final word = Word(
      id: 'w1',
      text: 'ephemeral',
      bookName: 'Book',
      userLevel: UserLevel.beginner,
      summary: WordSummary(
        definition: 'Lasting for only a short time.',
        mainSay: 'Lasting for only a short time.',
        useCases: const ['The beauty of the sunset was ephemeral.'],
        similarWords: const ['brief', 'fleeting', 'temporary'],
        detailedSummary: 'Lasting for only a short time.',
        generatedAt: DateTime(2025, 1, 1),
      ),
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quizProvider.overrideWith((ref) => _FakeQuizNotifier(
                QuizState(
                  session: QuizSession(
                    questions: [
                      QuizQuestion(
                        word: word,
                        mode: QuizMode.multipleChoice,
                        options: const [
                          'Lasting for only a short time.',
                          'Very careful and precise.',
                        ],
                        correctAnswer: 'Lasting for only a short time.',
                      ),
                    ],
                    mode: QuizMode.multipleChoice,
                  ),
                  generationNotice: 'Using standard quiz for this round.',
                ),
              )),
        ],
        child: const MaterialApp(
          home: QuizModeScreen(mode: QuizMode.multipleChoice),
        ),
      ),
    );

    expect(find.text('Using standard quiz for this round.'), findsOneWidget);
  });
}

class _FakeQuizNotifier extends QuizNotifier {
  _FakeQuizNotifier(QuizState initialState)
      : super(
          const [],
          const SettingsState(),
          _NoopAdaptiveQuizService(),
        ) {
    state = initialState;
  }

  @override
  Future<void> startSession({QuizMode? mode, List<Word>? dueWords}) async {}

  @override
  void submitAnswer(String answer) {}

  @override
  void submitFlashcard({required bool known}) {}

  @override
  void flipCard() {}

  @override
  void advance() {}

  @override
  void reset() {}
}

class _NoopAdaptiveQuizService extends AdaptiveQuizService {
  _NoopAdaptiveQuizService() : super();
}
