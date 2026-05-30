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
    final words = wordsAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(book.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Collection Stats'),
                  content: Text('${words.length} words in "${book.name}".\n'
                      '${words.where((w) => w.isPending).length} pending analysis.'),
                ),
              );
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
        child: words.isEmpty
            ? const Center(child: Text('No words in this collection yet.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: words.length,
                itemBuilder: (context, index) {
                  final word = words[index];
                  return _WordTile(word: word);
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddWordScreen()),
          );
          ref.read(wordRefreshProvider.notifier).refresh();
          ref.invalidate(bookListProvider);
        },
        backgroundColor: AppTheme.primaryBlue,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
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
