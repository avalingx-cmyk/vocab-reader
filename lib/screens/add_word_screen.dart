import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/word.dart';
import '../providers/word_provider.dart';
import '../providers/book_provider.dart';
import '../providers/model_readiness_provider.dart';
import '../providers/settings_provider.dart';
import '../services/analytics_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import 'settings_screen.dart';
import '../theme/app_theme.dart';

class AddWordScreen extends ConsumerStatefulWidget {
  const AddWordScreen({
    super.key,
    this.initialBookId,
    this.initialBookName,
  });

  final String? initialBookId;
  final String? initialBookName;

  @override
  ConsumerState<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends ConsumerState<AddWordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wordController = TextEditingController();
  final _bookController = TextEditingController();
  final _pageController = TextEditingController();
  final _contextController = TextEditingController();

  bool _isLoading = false;
  bool _isNewBook = false;
  String? _selectedBookId;
  String? _selectedBook;

  @override
  void initState() {
    super.initState();
    _selectedBookId = widget.initialBookId;
    _selectedBook = widget.initialBookName;
    if (widget.initialBookName != null) {
      _bookController.text = widget.initialBookName!;
    }
  }

  @override
  void dispose() {
    _wordController.dispose();
    _bookController.dispose();
    _pageController.dispose();
    _contextController.dispose();
    super.dispose();
  }

  Future<void> _saveWord() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final settings = ref.read(settingsProvider);
      final modelState = ref.read(modelReadinessProvider);
      final book = _selectedBookId != null
          ? null
          : await DatabaseService.instance.upsertBook(_bookController.text);
      final word = Word(
        id: const Uuid().v4(),
        text: _wordController.text.trim(),
        bookId: _selectedBookId ?? book!.id,
        bookName: _bookController.text.trim(),
        pageNumber: _pageController.text.isNotEmpty
            ? int.tryParse(_pageController.text)
            : null,
        context: _contextController.text.trim().isNotEmpty
            ? _contextController.text.trim()
            : null,
        userLevel: settings.userLevel,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPending: true,
      );

      await DatabaseService.instance.addWord(word);
      await DatabaseService.instance.addToQueue(word.id);
      await LocalAnalyticsService.instance.track(
        'word.added',
        payload: {
          'bookId': word.bookId,
          'hasContext': word.context != null,
          'learnerLevel': word.userLevel.name,
        },
      );
      
      ref.read(wordRefreshProvider.notifier).refresh();
      ref.invalidate(bookListProvider);

      if (modelState.isReady) {
        SyncService.instance.processPendingQueue();
      }

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context);
        final snackBar = buildWordSavedSnackBar(
          modelState: modelState,
          onOpenSettings: () {
            navigator.push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        );
        navigator.pop();
        messenger.showSnackBar(snackBar);
      }
    } catch (e) {
      await LocalAnalyticsService.instance.recordError(
        scope: 'word.add',
        error: e,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Capture Word'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Word Details'),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _wordController,
                label: 'The word',
                hint: 'e.g. Ephemeral',
                icon: Icons.text_fields_rounded,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a word' : null,
              ),
              const SizedBox(height: 20),
              Consumer(
                builder: (context, ref, child) {
                  final booksAsync = ref.watch(bookListProvider);
                  return booksAsync.when(
                    data: (books) {
                      if (books.isEmpty || _isNewBook) {
                        return _buildTextField(
                          controller: _bookController,
                          label: 'Source book',
                          hint: 'e.g. Meditations',
                          icon: Icons.auto_stories_rounded,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter the book name' : null,
                          suffixIcon: books.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.list_rounded),
                                  onPressed: () => setState(() => _isNewBook = false),
                                )
                              : null,
                        );
                      }
                      return _BookPickerField(
                        books: books,
                        selectedBook: _selectedBook,
                        onSelected: (v) {
                          if (v != null) {
                            final selected = books.firstWhere((b) => b.id == v);
                            setState(() {
                              _selectedBookId = selected.id;
                              _selectedBook = selected.name;
                              _bookController.text = selected.name;
                            });
                          }
                        },
                        onAddNew: () => setState(() {
                          _isNewBook = true;
                          _bookController.clear();
                          _selectedBookId = null;
                          _selectedBook = null;
                        }),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => _buildTextField(
                      controller: _bookController,
                      label: 'Source book',
                      hint: 'e.g. Meditations',
                      icon: Icons.auto_stories_rounded,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter the book name' : null,
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _pageController,
                label: 'Page (optional)',
                hint: 'e.g. 42',
                icon: Icons.tag_rounded,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('Usage Context'),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _contextController,
                label: 'Sentence context (optional)',
                hint: 'Write the sentence where you found the word...',
                icon: Icons.format_quote_rounded,
                maxLines: 4,
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveWord,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Add to My Library'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppTheme.primaryBlue, size: 20),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          floatingLabelStyle: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

SnackBar buildWordSavedSnackBar({
  required ModelReadinessState modelState,
  required VoidCallback onOpenSettings,
}) {
  final message = switch (modelState.status) {
    ModelReadinessStatus.ready =>
      'Word saved. BookBeam is creating the explanation now.',
    ModelReadinessStatus.unsupported =>
      'Word saved. Offline AI summaries work on Android in this build. Open Settings for details.',
    _ =>
      'Word saved. Download or repair the offline AI in Settings to create the explanation.',
  };

  return SnackBar(
    content: Text(message),
    backgroundColor: AppTheme.primaryBlue,
    action: modelState.status == ModelReadinessStatus.ready
        ? null
        : SnackBarAction(
            label: 'Open Settings',
            textColor: Colors.white,
            onPressed: onOpenSettings,
          ),
  );
}


// ── Premium book picker bottom sheet ─────────────────────────────────────────
class _BookPickerField extends StatelessWidget {
  final List<BookInfo> books;
  final String? selectedBook;
  final ValueChanged<String?> onSelected;
  final VoidCallback onAddNew;

  const _BookPickerField({
    required this.books,
    required this.selectedBook,
    required this.onSelected,
    required this.onAddNew,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedBook != null && selectedBook!.isNotEmpty;
    return FormField<String>(
      validator: (_) => (!hasSelection) ? 'Please select a book' : null,
      builder: (state) => GestureDetector(
        onTap: () => _showBookPicker(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: state.hasError
                    ? Border.all(color: Colors.redAccent, width: 1.5)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_stories_rounded, color: AppTheme.primaryBlue, size: 20),
                ),
                title: Text(
                  hasSelection ? selectedBook! : 'Select book',
                  style: TextStyle(
                    color: hasSelection
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: hasSelection ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 6),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showBookPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookPickerSheet(
        books: books,
        selectedBook: selectedBook,
        onSelected: (book) {
          Navigator.pop(context);
          onSelected(book);
        },
        onAddNew: () {
          Navigator.pop(context);
          onAddNew();
        },
      ),
    );
  }
}

class _BookPickerSheet extends StatelessWidget {
  final List<BookInfo> books;
  final String? selectedBook;
  final ValueChanged<String> onSelected;
  final VoidCallback onAddNew;

  const _BookPickerSheet({
    required this.books,
    required this.selectedBook,
    required this.onSelected,
    required this.onAddNew,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Text(
                  'Select a Book',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: books.length,
              separatorBuilder: (_, __) => const SizedBox(height: 0),
              itemBuilder: (context, index) {
                final book = books[index];
                final isSelected = book.name == selectedBook;
                return InkWell(
                  onTap: () => onSelected(book.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryBlue.withValues(alpha: 0.15)
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.menu_book_rounded,
                            color: isSelected ? AppTheme.primaryBlue : Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: isSelected ? AppTheme.primaryBlue : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${book.wordCount} ${book.wordCount == 1 ? 'word' : 'words'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          InkWell(
            onTap: onAddNew,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.add_rounded, color: AppTheme.primaryBlue, size: 22),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Add New Book',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
