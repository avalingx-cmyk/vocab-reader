import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/word.dart';
import '../models/user_level.dart';
import '../providers/word_provider.dart';
import '../providers/book_provider.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

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
    _pageController = TextEditingController(text: widget.word.pageNumber?.toString() ?? '');
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
    setState(() => _isLoading = true);

    try {
      final newText = _wordController.text.trim();
      final newBookName = _bookController.text.trim();
      final newPageNumber = _pageController.text.isNotEmpty ? int.tryParse(_pageController.text) : null;
      final newContext = _contextController.text.trim().isNotEmpty ? _contextController.text.trim() : null;

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

      if (shouldRegenerate && !widget.word.isPending) {
        await DatabaseService.instance.addToQueue(widget.word.id);
      }

      if (mounted) {
        ref.invalidate(wordListProvider(null));
        ref.invalidate(bookListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(shouldRegenerate ? 'Word updated and queued for AI analysis.' : 'Changes saved.'),
            backgroundColor: AppTheme.primaryBlue,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
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
        title: const Text('Edit Entry'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Basic Information'),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _wordController,
                label: 'Word',
                hint: 'e.g. Ephemeral',
                icon: Icons.text_fields_rounded,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a word' : null,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _bookController,
                label: 'Collection',
                hint: 'e.g. Meditations',
                icon: Icons.auto_stories_rounded,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter the book name' : null,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _pageController,
                label: 'Page',
                hint: 'Optional',
                icon: Icons.tag_rounded,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('Usage Context'),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _contextController,
                label: 'Context',
                hint: 'The sentence where you found this word...',
                icon: Icons.format_quote_rounded,
                maxLines: 4,
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _isLoading ? null : _updateWord,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60)),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes'),
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
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 1.2),
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
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
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
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}
