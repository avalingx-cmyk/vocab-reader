# BookBeam

BookBeam is a Flutter vocabulary app for readers. You capture unfamiliar words from books, generate offline AI explanations with the bundled local Cactus model, and review them later with flashcards or adaptive multiple-choice quizzes.

## What the app does

- Save words with book, page, and reading context
- Pick a learner level during onboarding and use it for future AI summaries
- Store words and books locally in SQLite
- Generate local AI summaries with the finalized `qwen3-0.6b` model
- Review words with flashcards and AI-generated adaptive multiple choice

## Current product shape

- AI path: local-only Cactus model
- Book data: real `books` table with `words.book_id`
- Quiz modes kept: flashcards and multiple choice
- No account required for v1
- Platform support: Android is the supported platform for full offline AI in this build

## Tech stack

- Flutter + Dart
- Riverpod
- SQLite via `sqflite`
- Dio for model download
- Local FFI-backed Cactus runtime

## Setup

1. Install Flutter and Android tooling.
2. Run `flutter pub get`.
3. Run `flutter test` to verify the project.
4. Launch with `flutter run`.
5. Open Settings in the app and download the local model if it is not already present.

## Local AI notes

- The app no longer requires API keys or `.env` configuration for summaries.
- The local model download is managed from Settings.
- If generation fails, use the Settings repair flow to remove and re-download the model.

## Development checks

- `flutter test`
- `flutter analyze lib test`
- `flutter build apk --debug`

## Release readiness

- Follow [RELEASE_CHECKLIST.md](C:/Users/selva/Desktop/Work/vocab-reader/RELEASE_CHECKLIST.md) for fresh-install QA, recovery testing, and signed Android release steps.
