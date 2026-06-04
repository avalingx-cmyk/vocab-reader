const int defaultPlayVersionCodeBase = 1000;

int computePlayVersionCode({
  required int runNumber,
  int base = defaultPlayVersionCodeBase,
  int offset = 0,
}) {
  if (runNumber < 1) {
    throw const FormatException(
        'GITHUB_RUN_NUMBER must be a positive integer.');
  }
  if (base < 0) {
    throw const FormatException(
        'PLAY_VERSION_CODE_BASE must be zero or greater.');
  }
  if (offset < 0) {
    throw const FormatException(
      'PLAY_VERSION_CODE_OFFSET must be zero or greater.',
    );
  }

  return base + runNumber + offset;
}

int computePlayVersionCodeFromEnvironment(Map<String, String> environment) {
  final runNumberRaw = environment['GITHUB_RUN_NUMBER'];
  final runNumber = int.tryParse(runNumberRaw ?? '');
  if (runNumber == null) {
    throw const FormatException(
      'GITHUB_RUN_NUMBER is required and must be an integer.',
    );
  }

  final baseRaw = _valueOrDefault(
    environment['PLAY_VERSION_CODE_BASE'],
    '$defaultPlayVersionCodeBase',
  );
  final base = int.tryParse(baseRaw);
  if (base == null) {
    throw const FormatException(
      'PLAY_VERSION_CODE_BASE must be an integer when provided.',
    );
  }

  final offsetRaw = _valueOrDefault(
    environment['PLAY_VERSION_CODE_OFFSET'],
    '0',
  );
  final offset = int.tryParse(offsetRaw);
  if (offset == null) {
    throw const FormatException(
      'PLAY_VERSION_CODE_OFFSET must be an integer when provided.',
    );
  }

  return computePlayVersionCode(
    runNumber: runNumber,
    base: base,
    offset: offset,
  );
}

String _valueOrDefault(String? value, String fallback) {
  if (value == null || value.trim().isEmpty) {
    return fallback;
  }
  return value.trim();
}
