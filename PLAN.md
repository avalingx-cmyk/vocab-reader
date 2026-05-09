# VocabReader Architecture Plan

**Project:** VocabReader - Vocabulary Learning Mobile App  
**Platform:** iOS & Android (Flutter)  
**Status:** 🚧 In Progress  
**Last Updated:** 2026-04-17

---

## 🎯 Overview

A mobile app that helps users learn vocabulary from books by:
- Adding words with book name & page number
- Auto-generating summaries (definition, meaning, use case)
- Adapting to user level (Beginner → Pro)
- Showing similar words for enhanced learning
- Working fully offline with AI queue

---

## 🏗️ Architecture

### Tech Stack

| Layer | Technology | Reason |
|-------|-----------|--------|
| **Framework** | Flutter + Dart | Cross-platform, native performance, beautiful UI |
| **State Management** | Riverpod | Simple, testable, scalable |
| **Database** | SQLite (sqflite) | Offline-first, local storage |
| **AI Service** | OpenAI API / Gemini | High-quality text generation |
| **HTTP** | dio | Robust networking, interceptors |
| **Storage** | shared_preferences | User preferences, cache |

---

## 📱 Features

### 1. Onboarding
- User level selection (Beginner/Intermediate/Advanced/Pro)
- AI provider selection (OpenAI/Gemini)
- API key input (optional, can add later)
- Tutorial walkthrough

### 2. Word Management
- Add word with:
  - Word text
  - Book name
  - Page number
  - Context (optional sentence)
- Edit/delete words
- Search/filter words
- Sort by date, book, alphabetically

### 3. AI Summary Generation
**When Online:**
```
User adds word → Queue for AI → Generate summary → Cache locally
```

**When Offline:**
```
User adds word → Save to queue → Show "pending" badge
When online → Process queue → Update with summaries
```

**Summary Includes:**
- **Definition** - Clear word meaning
- **Main Say** - Core concept in simple terms
- **Use Case** - Real-world examples
- **Similar Words** - Synonyms, antonyms, related terms
- **Level-adapted** - Content matches user level

### 4. Learning Features
- **Word Detail View** - Full summary with all sections
- **Similar Words** - Expand vocabulary network
- **Progress Stats** - Words learned, books tracked
- **Quiz Mode** (Future) - Test knowledge

### 5. Offline Strategy
- **Local Database** - SQLite stores all words
- **Queue System** - Pending AI requests stored locally
- **Background Sync** - Auto-process when online
- **Conflict Resolution** - Last-write-wins for edits

---

## 🗄️ Data Models

### Word Model
```dart
class Word {
  final String id;
  final String text;
  final String bookName;
  final int pageNumber;
  final String? context;
  final UserLevel userLevel;
  final WordSummary? summary;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPending;  // Waiting for AI
}
```

### WordSummary Model
```dart
class WordSummary {
  final String definition;
  final String mainSay;
  final List<String> useCases;
  final List<String> similarWords;
  final String detailedSummary;
  final DateTime generatedAt;
}
```

### UserLevel Enum
```dart
enum UserLevel {
  beginner,      // Simple explanations, basic vocabulary
  intermediate,  // Standard explanations, common synonyms
  advanced,      // Technical depth, nuanced meanings
  pro           // Expert-level, etymology, rare synonyms
}
```

### Book Model
```dart
class Book {
  final String id;
  final String name;
  final String? author;
  final int wordCount;
  final DateTime lastAccessed;
}
```

### PendingQueue Model
```dart
class PendingQueue {
  final String wordId;
  final DateTime queuedAt;
  final int retryCount;
}
```

---

## 🎨 UI/UX Design

### Screens

| Screen | Purpose |
|--------|---------|
| **Onboarding** | First-time setup (level, AI provider) |
| **Home** | Dashboard with stats, recent words, quick add |
| **Word List** | All words with search/filter |
| **Add Word** | Form to add new word |
| **Word Detail** | Full summary view |
| **Books** | List of books being read |
| **Settings** | AI config, level change, data export |

### Key UI Components

- **WordCard** - Compact word display with pending badge
- **SummaryCard** - Expandable sections for each summary part
- **LevelSelector** - Visual level picker with descriptions
- **BookSelector** - Dropdown with recent books + "add new"
- **PendingBadge** - Shows queue status

### Design System

- **Colors:** Primary (blue), Secondary (orange), Background (light/dark)
- **Typography:** Readable fonts, hierarchy for definitions
- **Spacing:** Comfortable reading experience
- **Animations:** Smooth transitions, loading states

---

## 🔧 Services

### DatabaseService
```dart
class DatabaseService {
  Future<void> init();
  Future<Word> addWord(Word word);
  Future<Word> updateWord(Word word);
  Future<void> deleteWord(String id);
  Future<List<Word>> getWords({String? bookName, String? search});
  Future<List<Book>> getBooks();
  Future<List<PendingQueue>> getPendingQueue();
}
```

### AIService
```dart
class AIService {
  Future<WordSummary> generateSummary({
    required String word,
    required String? context,
    required UserLevel level,
    required String provider,  // 'openai' or 'gemini'
    required String apiKey,
  });
  
  Future<bool> testConnection(String provider, String apiKey);
}
```

### SyncService
```dart
class SyncService {
  Future<void> processQueue();
  Future<void> syncIfOnline();
  Stream<bool> get onlineStatus;
}
```

---

## 🌐 API Integration

### OpenAI Prompt
```
Word: {word}
Context: {context}
User Level: {level}

Generate:
1. Definition (1-2 sentences, {level} level)
2. Main Say (core concept in simple terms)
3. Use Cases (3 real-world examples)
4. Similar Words (5 synonyms/antonyms appropriate for {level})
5. Detailed Summary (paragraph explaining the word deeply)
```

### Gemini Prompt
Same structure, adapted for Gemini's format.

---

## 📊 Database Schema

### Tables

```sql
-- Words table
CREATE TABLE words (
  id TEXT PRIMARY KEY,
  text TEXT NOT NULL,
  book_name TEXT NOT NULL,
  page_number INTEGER,
  context TEXT,
  user_level TEXT NOT NULL,
  definition TEXT,
  main_say TEXT,
  use_cases TEXT,  -- JSON array
  similar_words TEXT,  -- JSON array
  detailed_summary TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  is_pending INTEGER DEFAULT 0
);

-- Books table
CREATE TABLE books (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  author TEXT,
  word_count INTEGER DEFAULT 0,
  last_accessed INTEGER
);

-- Pending queue
CREATE TABLE pending_queue (
  word_id TEXT PRIMARY KEY,
  queued_at INTEGER NOT NULL,
  retry_count INTEGER DEFAULT 0,
  FOREIGN KEY (word_id) REFERENCES words(id)
);

-- Settings
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT
);
```

---

## 🚀 Implementation Phases

### Phase 1: Core Setup ✅
- [x] Project structure
- [x] Flutter initialization (Main app & providers set up)
- [x] Database setup (Models and database service exist)
- [x] Basic UI scaffold (Bottom Navigation, Screens created)

### Phase 2: Word Management ✅
- [x] Add word form
- [x] Word list screen (Home screen with search)
- [x] Database CRUD (Edit & Delete implemented)
- [x] Search/filter

### Phase 3: AI Integration ✅
- [x] OpenAI / Gemini service (AIService integration completed)
- [x] Queue system (Pending queue processing in SyncService)
- [x] Offline handling (SyncService with retry logic and backoff)

### Phase 4: User Experience ✅
- [x] Onboarding flow
- [x] Level selection
- [x] Word detail view
- [x] Settings screen
- [x] Book management

### Phase 5: Polish 🚧
- [x] Animations (Search bar animation done, others pending)
- [ ] Error handling (Sync retry implemented, need global error handling)
- [ ] Testing
- [ ] Documentation (PROGRESS.md & PLAN.md maintained)

---

## 📝 Current Status

**In Progress:** Phase 5: Polish 🚧
**Next:** Focus on global error handling, comprehensive testing, and finalizing UI polish.

---

**Planned by:** Monkey D. Luffy 🔥  
**Framework:** DGSD v1.0
