# BookBeam Progress

## Current state

- Local-only AI runtime is active
- Learner level is chosen in onboarding and reused for future summaries
- Books are backed by the `books` table with `words.book_id`
- Benchmarking and cloud-provider UX were removed from the product flow
- Flashcards and adaptive multiple-choice remain in scope

## Recent launch-readiness work

- Added model readiness and repair UX
- Added local analytics and recent error logging
- Added recovery surfaces for pending summary retries
- Added Android release signing documentation
- Added support and diagnostics visibility in Settings

## Verification baseline

- `flutter analyze lib test`
- `flutter test`
- `flutter build apk --debug`

Use [RELEASE_CHECKLIST.md](C:/Users/selva/Desktop/Work/vocab-reader/RELEASE_CHECKLIST.md) for the full manual QA path before distribution.
