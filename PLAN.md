# BookBeam Plan

This project now ships as a local-first Android vocabulary app.

## Product focus

- Save unfamiliar words from books
- Keep books as real records in SQLite
- Generate offline AI explanations with the local Cactus model
- Review words with flashcards and adaptive multiple-choice

## Out of scope for the current release

- Cloud AI providers
- API keys or `.env` setup
- Extra quiz modes beyond flashcards and multiple choice
- Benchmarking or model bake-off tooling

## Launch priorities

1. Keep the Android offline-AI flow reliable on fresh installs.
2. Make model readiness and recovery clear in the UI.
3. Keep books, words, and review state persistent across restarts.
4. Validate signed Android release builds and manual QA with the release checklist.

For current setup and release steps, use [README.md](C:/Users/selva/Desktop/Work/vocab-reader/README.md) and [RELEASE_CHECKLIST.md](C:/Users/selva/Desktop/Work/vocab-reader/RELEASE_CHECKLIST.md).
