import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/word.dart';
import '../models/user_level.dart';
import '../providers/word_provider.dart';
import '../providers/book_provider.dart';
import '../services/database_service.dart';

class EditWordScreen extends ConsumerStatefulWidget {
  final Word word;

  const EditWordScreen({
    super.key,
    required this.word,
  });

  @override
  ConsumerState<EditWordScreen> createState() => _EditWordScreenState();
}

class _EditWordScreenState extends ConsumerState<EditWordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _wordController;
  late final TextEditingController _bookController;
  late final TextEditingController _pageController;
  late final TextEditingController _contextController;

  late UserLevel _selectedLevel;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _wordController = TextEditingController(text: widget.word.text);
    _bookController = TextEditingController(text: widget.word.bookName);
    _pageController = TextEditingController(
      text: widget.word.pageNumber?.toString() ?? '',
    );
    _contextController = TextEditingController(text: widget.word.context ?? '');
    _selectedLevel = widget.word.userLevel;
  }

  @override
  void dispose() {
    _wordController.dispose();
    _bookController.dispose();
    _pageController.dispose();
    _contextController.dispose();
    super.dispose();
  }

  Future<void> _updateWord() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final newText = _wordController.text.trim();
      final newBookName = _bookController.text.trim();
      final newPageNumber = _pageController.text.isNotEmpty
          ? int.tryParse(_pageController.text)
          : null;
      final newContext = _contextController.text.trim().isNotEmpty
          ? _contextController.text.trim()
          : null;

      // Check if word text changed - if so, mark as pending to regenerate summary
      final textChanged = newText != widget.word.text;
      final levelChanged = _selectedLevel != widget.word.userLevel;
      final shouldRegenerate = textChanged || levelChanged;

      final updatedWord = widget.word.copyWith(
        text: newText,
        bookName: newBookName,
        pageNumber: newPageNumber,
        context: newContext,
        userLevel: _selectedLevel,
        isPending: shouldRegenerate ? true : widget.word.isPending,
        updatedAt: DateTime.now(),
      );

      await DatabaseService.instance.updateWord(updatedWord);

      // If text or level changed, add to queue for regeneration
      if (shouldRegenerate && !widget.word.isPending) {
        await DatabaseService.instance.addToQueue(widget.word.id);
      }

      if (mounted) {
        ref.invalidate(wordListProvider(null));
        ref.invalidate(bookListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              shouldRegenerate
                  ? 'Word updated! AI summary will be regenerated.'
                  : 'Word updated!',
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Word'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _wordController,
                decoration: const InputDecoration(
                  labelText: 'Word *',
                  hintText: 'Enter the word you want to learn',
                  prefixIcon: Icon(Icons.text_fields),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a word';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bookController,
                decoration: const InputDecoration(
                  labelText: 'Book Name *',
                  hintText: 'Which book is this word from?',
                  prefixIcon: Icon(Icons.book),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the book name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pageController,
                decoration: const InputDecoration(
                  labelText: 'Page Number',
                  hintText: 'Optional - which page is this word on?',
                  prefixIcon: Icon(Icons.numbers),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contextController,
                decoration: const InputDecoration(
                  labelText: 'Context (Optional)',
                  hintText: 'The sentence or paragraph where you found this word',
                  prefixIcon: Icon(Icons.format_quote),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Text(
                'Your Level',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'This affects how the AI explains the word',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              ...UserLevel.values.map((level) => RadioListTile<UserLevel>(
                title: Text(level.displayName),
                subtitle: Text(
                  level.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                value: level,
                groupValue: _selectedLevel,
                onChanged: (value) {
                  setState(() {
                    _selectedLevel = value!;
                  });
                },
              )),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _updateWord,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? 'Saving...' : 'Update Word'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
