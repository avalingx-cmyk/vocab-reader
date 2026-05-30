enum UserLevel {
  beginner,
  intermediate,
  upperIntermediate,
  advanced,
  pro;

  String get displayName {
    switch (this) {
      case UserLevel.beginner:
        return 'Beginner';
      case UserLevel.intermediate:
        return 'Intermediate';
      case UserLevel.upperIntermediate:
        return 'Upper Intermediate';
      case UserLevel.advanced:
        return 'Advanced';
      case UserLevel.pro:
        return 'Pro';
    }
  }

  String get description {
    switch (this) {
      case UserLevel.beginner:
        return 'Simple explanations, basic vocabulary';
      case UserLevel.intermediate:
        return 'Standard explanations, common synonyms';
      case UserLevel.upperIntermediate:
        return 'Clear explanations with some nuance';
      case UserLevel.advanced:
        return 'Technical depth, nuanced meanings';
      case UserLevel.pro:
        return 'Expert-level, etymology, rare synonyms';
    }
  }

  static UserLevel fromString(String value) {
    return UserLevel.values.firstWhere(
      (e) => e.name == value,
      orElse: () => UserLevel.beginner,
    );
  }
}
