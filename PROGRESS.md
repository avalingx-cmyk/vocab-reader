# VocabReader Progress

## Completed Features

### 1. Riverpod Providers (lib/providers/)
- **word_provider.dart** - wordListProvider, pendingWordsProvider, wordProvider, wordSearchProvider, filteredWordsProvider, wordRefreshProvider
- **book_provider.dart** - bookListProvider, bookWordsProvider with BookInfo model
- **settings_provider.dart** - settingsProvider with SettingsState/SettingsNotifier
- **sync_provider.dart** - syncProvider with SyncState/SyncNotifier
- **connectivity_provider.dart** - connectivityProvider using dart:io DNS lookup

### 2. Sync Service (lib/services/sync_service.dart)
- Process pending queue sequentially
- AIService integration for summary generation
- Retry logic with max 3 retries and exponential backoff
- Sync progress tracking via streams

### 3. Search Functionality (HomeScreen)
- Animated search bar that expands/collapses
- Real-time filtering via filteredWordsProvider
- "No results found" state
- 300ms debounce on search input

### 4. Edit Word Feature (lib/screens/edit_word_screen.dart)
- Pre-filled form with existing word data
- Same layout as AddWordScreen
- Detects text/level changes and marks as pending for regeneration
- Provider invalidation on save

### 5. Delete Word Feature (WordDetailScreen)
- Delete confirmation dialog
- Removes from pending queue if applicable
- Provider invalidation after deletion
- Navigation back after delete

### 6. Book Management (lib/screens/books_screen.dart)
- List all books with word count, last accessed, progress
- Tap to filter (shows snackbar - full filter requires navigation state)
- Long press for rename/delete options
- Progress bar showing words with summaries vs pending

### 7. App Navigation
- BottomNavigationBar with Words and Books tabs
- IndexedStack for state preservation
- navIndexProvider for navigation state

### 8. Updated Screens
- **HomeScreen** - Added search + BottomNavigationBar
- **AddWordScreen** - Uses providers for refresh
- **WordDetailScreen** - Edit/delete functionality with provider integration
- **SettingsScreen** - Uses settingsProvider
- **main.dart** - App startup with onboarding check

### 9. AI Service & Cross-Platform Fixes (Phase 5)
- **Gemini Model Fix:** Updated AIService to use stable `gemini-1.5-flash` endpoint.
- **Windows Support:** Added platform-aware library loading for `llama_cpp_dart` on Windows, Linux, and Android.
- **Sync Resilience:** Fixed `SyncService` to unconditionally trigger queue processing on manual sync requests.
- **Logging & Debugging:** Enhanced logging in `AIService` and `SyncService` for better observability of network and parsing errors.
- **Robust Parsing:** Added safety checks for Gemini JSON response candidates and parts to prevent null-pointer crashes.

### 10. Android Native Library Bundling (Phase 6)
- **Root Cause:** `llama_cpp_dart` is not a Flutter plugin, so `libmtmd.so` was never bundled in APK.
- **Fix:** Created `android/llamalib/` Gradle module that builds `libmtmd.so` via CMake+NDK.
- **Source Setup:** Created `llama_cpp_native/src/` with CMakeLists.txt, OpenCL headers/libs, and llama.cpp source at the correct commit (`4ffc47cb`).
- **CMake Fix:** Added missing `models/*.cpp` source files to mtmd library build (needed for clip graph symbols).
- **NDK Version:** Fixed from 29 to 28.2 (installed version).
- **C++ Runtime:** Switched from `c++_shared` to `c++_static` to avoid conflicts with Flutter engine.
- **Build Wiring:** Added `implementation(project(":llamalib"))` to `app/build.gradle.kts` and `include(":llamalib")` to `settings.gradle.kts`.
- **minSdk:** Bumped from `flutter.minSdkVersion` (21) to 24 to match llamalib requirement.
- **Build Verified:** `libmtmd.so` (1.5MB arm64, 1.6MB x86_64) builds successfully with all dependencies (llama, ggml, OpenCL, OpenMP).

## File Structure After Changes
```
lib/
├── main.dart (UPDATED - platform-aware Llama init)
├── models/
│   ├── user_level.dart (unchanged)
│   └── word.dart (unchanged)
├── providers/
│   ├── word_provider.dart (NEW)
│   ├── book_provider.dart (NEW)
│   ├── settings_provider.dart (NEW)
│   ├── sync_provider.dart (NEW)
│   └── connectivity_provider.dart (NEW)
├── screens/
│   ├── home_screen.dart (UPDATED - search + nav)
│   ├── add_word_screen.dart (UPDATED - use providers)
│   ├── word_detail_screen.dart (UPDATED - edit/delete)
│   ├── edit_word_screen.dart (NEW)
│   ├── books_screen.dart (NEW)
│   ├── onboarding_screen.dart (unchanged)
│   └── settings_screen.dart (UPDATED - use providers)
├── services/
│   ├── ai_service.dart (UPDATED - Gemini fix + logging)
│   ├── database_service.dart (unchanged)
│   ├── sync_service.dart (UPDATED - trigger logic + cleanup)
│   └── local_ai_service.dart (UPDATED - platform-aware Isolate)
```
