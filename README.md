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

## Play Console automation

This repo now includes GitHub Actions + fastlane automation for Google Play:

- Push to `develop` -> build a signed AAB and deploy to the configured closed testing track
- Push to `main` -> build a signed AAB and wait for GitHub `production` environment approval before deploying to production
- Manual runs are also available through `workflow_dispatch`

Files:

- [.github/workflows/play-deploy.yml](C:/Users/selva/Desktop/Work/vocab-reader/.github/workflows/play-deploy.yml)
- [fastlane/Appfile](C:/Users/selva/Desktop/Work/vocab-reader/fastlane/Appfile)
- [fastlane/Fastfile](C:/Users/selva/Desktop/Work/vocab-reader/fastlane/Fastfile)
- [Gemfile](C:/Users/selva/Desktop/Work/vocab-reader/Gemfile)

Required GitHub secrets:

- `PLAY_SERVICE_ACCOUNT_JSON`
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_STORE_PASSWORD`

Optional GitHub repository variables:

- `PLAY_CLOSED_TRACK`
  Use this if your Play Console testing track has a custom name. If not set, the workflow uses `internal`, which is the safest default for first automated uploads.
- `PLAY_VERSION_CODE_BASE`
  Optional. Defaults to `1000` in CI so Play uploads start well above the local `pubspec.yaml` build number. The workflow calculates:
  `build-number = PLAY_VERSION_CODE_BASE + github.run_number + PLAY_VERSION_CODE_OFFSET`
- `PLAY_VERSION_CODE_OFFSET`
  Optional extra bump when your current Play `versionCode` is already above the computed base + run number.

Required GitHub environment:

- Create an environment named `production`
- Add required reviewers if you want approval before production uploads
