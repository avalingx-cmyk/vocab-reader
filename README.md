# VocabReader 📚

A Flutter mobile app for learning vocabulary from books with AI-powered summaries.

## Features

- 📖 **Book-based vocabulary tracking** - Save words with book name & page number
- 🤖 **AI-generated summaries** - Auto-generate definitions, meanings, use cases
- 🎯 **User-level adaptation** - Content adapts to Beginner/Intermediate/Advanced/Pro levels
- 🔗 **Similar words** - Learn synonyms and related vocabulary
- 📱 **Fully offline** - Works without internet (AI summaries queued when offline)

## Tech Stack

- **Framework:** Flutter + Dart
- **State Management:** Riverpod
- **Database:** SQLite (sqflite)
- **AI:** OpenAI API / Google Gemini

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── word.dart
│   ├── book.dart
│   └── user_level.dart
├── screens/                  # UI screens
│   ├── home_screen.dart
│   ├── add_word_screen.dart
│   ├── word_detail_screen.dart
│   ├── word_list_screen.dart
│   └── onboarding_screen.dart
├── widgets/                  # Reusable widgets
│   ├── word_card.dart
│   ├── level_selector.dart
│   └── summary_card.dart
├── services/                 # Business logic
│   ├── database_service.dart
│   ├── ai_service.dart
│   └── sync_service.dart
└── utils/                    # Helpers
    ├── constants.dart
    └── extensions.dart
```

## Setup

1. Install Flutter: https://flutter.dev/docs/get-started/install
2. Run `flutter pub get`
3. Add API keys to `.env`:
   ```
   OPENAI_API_KEY=your_key_here
   # OR
   GEMINI_API_KEY=your_key_here
   ```
4. Run `flutter run`

## Screenshots

Coming soon...

---

**Built with ❤️ by Monkey D. Luffy**
