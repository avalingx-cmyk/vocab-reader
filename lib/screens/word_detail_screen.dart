import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/word.dart';
import '../providers/word_provider.dart';
import '../providers/book_provider.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import 'edit_word_screen.dart';
import '../theme/app_theme.dart';

class WordDetailScreen extends ConsumerStatefulWidget {
  final Word word;

  const WordDetailScreen({
    super.key,
    required this.word,
  });

  @override
  ConsumerState<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends ConsumerState<WordDetailScreen> {
  Word? _currentWord;
  StreamSubscription<SyncStatus>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _currentWord = widget.word;
    _loadWord();

    _syncSubscription = SyncService.instance.syncStatusStream.listen((status) {
      if (status == SyncStatus.completed || status == SyncStatus.idle) {
        _loadWord();
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadWord() async {
    final freshWord = await DatabaseService.instance.getWord(widget.word.id);
    if (freshWord != null && mounted) {
      setState(() {
        _currentWord = freshWord;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final word = _currentWord ?? widget.word;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(word.text),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => EditWordScreen(word: word)),
              );
              if (result == true && context.mounted) {
                ref.invalidate(wordListProvider(null));
                Navigator.of(context).pop();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _showDeleteConfirmation(context, ref, word),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, word),
            const SizedBox(height: 32),
            if (word.isPending)
              _buildStatusBanner(
                context,
                icon: Icons.auto_awesome_rounded,
                title: 'AI Summary Pending',
                message:
                    'Our AI is currently analyzing this word. It will appear here shortly.',
                color: AppTheme.accentAmber,
              )
            else if (word.summary != null)
              _buildSummary(context, word)
            else
              _buildStatusBanner(
                context,
                icon: Icons.info_outline_rounded,
                title: 'No Summary Available',
                message:
                    'We couldn\'t generate a summary for this word at the moment.',
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Word word) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              word.text,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                word.userLevel.displayName,
                style: const TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.auto_stories_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              '${word.bookName}${word.pageNumber != null ? ' • Page ${word.pageNumber}' : ''}',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        if (word.context != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.format_quote_rounded,
                        size: 16,
                        color: AppTheme.primaryBlue.withValues(alpha: 0.5)),
                    const SizedBox(width: 8),
                    Text('CONTEXT',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '"${word.context}"',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.5,
                      ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusBanner(BuildContext context,
      {required IconData icon,
      required String title,
      required String message,
      required Color color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 48),
          const SizedBox(height: 16),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18, color: color)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: color.withValues(alpha: 0.8), height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context, Word word) {
    final summary = word.summary!;
    return Column(
      children: [
        _buildSectionCard(
          context,
          icon: Icons.menu_book_rounded,
          title: 'Definition',
          content: summary.definition,
        ),
        const SizedBox(height: 20),
        _buildSectionCard(
          context,
          icon: Icons.lightbulb_outline_rounded,
          title: 'Example Use Cases',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: summary.useCases
                .map((useCase) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Icon(Icons.circle,
                                size: 6, color: AppTheme.primaryBlue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(useCase,
                                  style: const TextStyle(height: 1.5))),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionCard(
          context,
          icon: Icons.compare_arrows_rounded,
          title: 'Similar Words',
          content: summary.similarWords.join(', '),
        ),
      ],
    );
  }

  Widget _buildSectionCard(BuildContext context,
      {required IconData icon,
      required String title,
      String? content,
      Widget? child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (content != null)
            Text(
              content,
              style: TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Theme.of(context).colorScheme.onSurface),
            ),
          if (child != null) child,
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, Word word) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Word?'),
        content: const Text(
            'This will remove the word and its AI summary from your library.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (word.isPending) {
                await DatabaseService.instance.removeFromQueue(word.id);
              }
              await DatabaseService.instance.deleteWord(word.id);
              // Invalidate all affected providers so book lists and word lists refresh
              ref.invalidate(wordListProvider(null));
              ref.invalidate(wordListProvider(word.bookName));
              ref.invalidate(filteredWordsProvider(null));
              ref.invalidate(bookListProvider);
              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to list
              }
            },
            child:
                const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
