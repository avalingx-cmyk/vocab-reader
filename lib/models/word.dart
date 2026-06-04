import 'user_level.dart';

const _unset = Object();

class Word {
  final String id;
  final String text;
  final String? bookId;
  final String bookName;
  final int? pageNumber;
  final String? context;
  final UserLevel userLevel;
  final WordSummary? summary;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPending;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;
  final int successCount;
  final int failureCount;

  Word({
    required this.id,
    required this.text,
    this.bookId,
    required this.bookName,
    this.pageNumber,
    this.context,
    required this.userLevel,
    this.summary,
    required this.createdAt,
    required this.updatedAt,
    this.isPending = false,
    this.lastReviewedAt,
    this.nextReviewAt,
    this.successCount = 0,
    this.failureCount = 0,
  });

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      id: json['id'] as String,
      text: json['text'] as String,
      bookId: json['bookId'] as String?,
      bookName: json['bookName'] as String,
      pageNumber: json['pageNumber'] as int?,
      context: json['context'] as String?,
      userLevel: UserLevel.fromString(json['userLevel'] as String),
      summary: json['summary'] != null
          ? WordSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isPending: json['isPending'] as bool? ?? false,
      lastReviewedAt: json['lastReviewedAt'] != null
          ? DateTime.parse(json['lastReviewedAt'] as String)
          : null,
      nextReviewAt: json['nextReviewAt'] != null
          ? DateTime.parse(json['nextReviewAt'] as String)
          : null,
      successCount: json['successCount'] as int? ?? 0,
      failureCount: json['failureCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'bookId': bookId,
      'bookName': bookName,
      'pageNumber': pageNumber,
      'context': context,
      'userLevel': userLevel.name,
      'summary': summary?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPending': isPending,
      'lastReviewedAt': lastReviewedAt?.toIso8601String(),
      'nextReviewAt': nextReviewAt?.toIso8601String(),
      'successCount': successCount,
      'failureCount': failureCount,
    };
  }

  Word copyWith({
    String? id,
    String? text,
    Object? bookId = _unset,
    String? bookName,
    Object? pageNumber = _unset,
    Object? context = _unset,
    UserLevel? userLevel,
    Object? summary = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPending,
    Object? lastReviewedAt = _unset,
    Object? nextReviewAt = _unset,
    int? successCount,
    int? failureCount,
  }) {
    return Word(
      id: id ?? this.id,
      text: text ?? this.text,
      bookId: identical(bookId, _unset) ? this.bookId : bookId as String?,
      bookName: bookName ?? this.bookName,
      pageNumber: identical(pageNumber, _unset)
          ? this.pageNumber
          : pageNumber as int?,
      context:
          identical(context, _unset) ? this.context : context as String?,
      userLevel: userLevel ?? this.userLevel,
      summary: identical(summary, _unset)
          ? this.summary
          : summary as WordSummary?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPending: isPending ?? this.isPending,
      lastReviewedAt: identical(lastReviewedAt, _unset)
          ? this.lastReviewedAt
          : lastReviewedAt as DateTime?,
      nextReviewAt: identical(nextReviewAt, _unset)
          ? this.nextReviewAt
          : nextReviewAt as DateTime?,
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
    );
  }
}

class WordSummary {
  final String definition;
  final String mainSay;
  final List<String> useCases;
  final List<String> similarWords;
  final String detailedSummary;
  final DateTime generatedAt;

  WordSummary({
    required this.definition,
    required this.mainSay,
    required this.useCases,
    required this.similarWords,
    required this.detailedSummary,
    required this.generatedAt,
  });

  factory WordSummary.fromJson(Map<String, dynamic> json) {
    return WordSummary(
      definition: json['definition'] as String,
      mainSay: json['mainSay'] as String,
      useCases: List<String>.from(json['useCases'] as List),
      similarWords: List<String>.from(json['similarWords'] as List),
      detailedSummary: json['detailedSummary'] as String,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'definition': definition,
      'mainSay': mainSay,
      'useCases': useCases,
      'similarWords': similarWords,
      'detailedSummary': detailedSummary,
      'generatedAt': generatedAt.toIso8601String(),
    };
  }
}
