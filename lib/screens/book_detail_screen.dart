import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/word.dart';
import '../providers/book_provider.dart';
import '../providers/word_provider.dart';
import '../theme/app_theme.dart';
import 'word_detail_screen.dart';
import 'add_word_screen.dart';

class BookDetailScreen extends ConsumerWidget {
  final BookInfo book;

  const BookDetailScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordsAsync = ref.watch(wordListProvider(book.name));

    return Scaffold(
      appBar: AppBar(
        title: Text(book.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              // Show book stats summary
              _showBookStats(context);
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: wordsAsync.when(
          data: (words) {
            if (words.isEmpty) {
              return const Center(child: Text('No words in this collection yet.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: words.length,
              itemBuilder: (context, index) {
                final word = words[index];
                return _WordTile(word: word);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddWordScreen()),
          );
          ref.invalidate(wordListProvider(book.name));
          ref.invalidate(bookListProvider);
        },
        backgroundColor: AppTheme.primaryBlue,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  void _showBookStats(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(book.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            _buildStatRow(context, 'Total Words', book.wordCount.toString(), Icons.style_rounded),
            const SizedBox(height: 16),
            _buildStatRow(context, 'Pending AI', book.pendingCount.toString(), Icons.auto_awesome_rounded),
            const SizedBox(height: 16),
            _buildStatRow(context, 'Learning Progress', '${(book.progress * 100).toInt()}%', Icons.trending_up_rounded),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryBlue),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}

class _WordTile extends StatelessWidget {
  final Word word;
  const _WordTile({required this.word});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(
          word.text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryBlue),
        ),
        subtitle: word.summary != null
            ? Text(
                word.summary!.definition,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              )
            : const Text('Analyzing...', style: TextStyle(fontStyle: FontStyle.italic)),
        trailing: word.isPending
            ? const Icon(Icons.sync_rounded, size: 18, color: AppTheme.accentAmber)
            : const Icon(Icons.chevron_right_rounded),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => WordDetailScreen(word: word)),
          );
        },
      ),
    );
  }
}
