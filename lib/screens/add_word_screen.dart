import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/word.dart';
import '../models/user_level.dart';
import '../services/database_service.dart';
import '../services/ai_service.dart';

class AddWordScreen extends ConsumerStatefulWidget {
  const AddWordScreen({super.key});

  @override
  ConsumerState<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends ConsumerState<AddWordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wordController = TextEditingController();
  final _bookController = TextEditingController();
  final _pageController = TextEditingController();
  final _contextController = TextEditingController();
  
  UserLevel _selectedLevel = UserLevel.beginner;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserLevel();
  }

  Future<void> _loadUserLevel() async {
    final levelStr = await DatabaseService.instance.getSetting('user_level');
    if (levelStr != null) {
      setState(() {
        _selectedLevel = UserLevel.fromString(levelStr);
      });
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

    setState(() {
      _isLoading = true;
    });

    try {
      final word = Word(
        id: const Uuid().v4(),
        text: _wordController.text.trim(),
        bookName: _bookController.text.trim(),
        pageNumber: _pageController.text.isNotEmpty
            ? int.tryParse(_pageController.text)
            : null,
        context: _contextController.text.trim().isNotEmpty
            ? _contextController.text.trim()
            : null,
        userLevel: _selectedLevel,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPending: true,
      );

      await DatabaseService.instance.addWord(word);
      await DatabaseService.instance.addToQueue(word.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Word saved! AI summary will be generated when online.')),
        );
        Navigator.of(context).pop();
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
        title: const Text('Add Word'),
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
                  onPressed: _isLoading ? null : _saveWord,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? 'Saving...' : 'Save Word'),
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
