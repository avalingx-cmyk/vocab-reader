# BookBeam Release Checklist

## Product promise

- Local-first vocabulary learning
- No account required
- Android is the supported platform for full offline AI in this release
- Books, word capture, summaries, flashcards, and adaptive multiple choice are the core value

## Fresh install QA

1. Install a clean build on an Android device or emulator.
2. Complete onboarding and choose a learner level.
3. Confirm Home loads without crashes.
4. Open Settings and verify offline AI status is shown clearly.
5. Download the offline model.
6. Confirm the model reaches the ready state.

## Core user flow QA

1. Add a new word with a book and optional context.
2. Confirm the word appears in the library immediately.
3. Confirm summary generation starts or the app clearly explains why it is pending.
4. Verify the finished summary appears after generation completes.
5. Restart the app and confirm the word, book link, and summary persist.

## Failure and recovery QA

1. Remove or repair the model from Settings.
2. Add a new word while the model is unavailable.
3. Confirm the app explains that the word was saved and the summary is pending.
4. Re-download the model.
5. Use the retry flow from Home or Review.
6. Confirm the pending summary is generated successfully.
7. Verify offline/online transitions do not lose queued words.

## Review QA

1. Start a flashcard review session.
2. Complete the session and verify progress persists.
3. Start an adaptive multiple-choice session.
4. Verify AI-built questions render correctly.
5. Finish the session and confirm results/persistence work.

## Build and signing

## Debug verification

- `flutter analyze lib test`
- `flutter test`
- `flutter build apk --debug`

## Release signing setup

1. Create `android/key.properties` with:
   - `storeFile=...`
   - `storePassword=...`
   - `keyAlias=...`
   - `keyPassword=...`
2. Place the keystore file at the configured location.
3. Confirm `android/app/build.gradle.kts` picks up the release signing config automatically.

## Release build verification

- `flutter build apk --release`
- `flutter build appbundle --release`

If `key.properties` is missing, release builds fall back to debug signing for local verification only. Do not distribute those artifacts.
