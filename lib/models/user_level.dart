enum UserLevel {
  beginner,
  intermediate,
  pro;

  String get displayName {
    switch (this) {
      case UserLevel.beginner:
        return 'Beginner';
      case UserLevel.intermediate:
        return 'Intermediate';
      case UserLevel.pro:
        return 'Pro';
    }
  }

  String get description {
    switch (this) {
      case UserLevel.beginner:
        return 'Simple explanations, basic vocabulary';
      case UserLevel.intermediate:
        return 'Clear explanations with common nuance and stronger vocabulary';
      case UserLevel.pro:
        return 'Expert-level, etymology, rare synonyms';
    }
  }

  static UserLevel fromString(String value) {
    switch (value) {
      case 'beginner':
        return UserLevel.beginner;
      case 'intermediate':
      case 'upperIntermediate':
        return UserLevel.intermediate;
      case 'advanced':
      case 'pro':
        return UserLevel.pro;
      default:
        return UserLevel.beginner;
    }
  }
}
