import 'package:bookbeam/services/play_version_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the default base and zero offset', () {
    final buildNumber = computePlayVersionCode(
      runNumber: 42,
    );

    expect(buildNumber, 1042);
  });

  test('adds both custom base and offset', () {
    final buildNumber = computePlayVersionCode(
      runNumber: 42,
      base: 2000,
      offset: 75,
    );

    expect(buildNumber, 2117);
  });

  test('parses environment values for CI usage', () {
    final buildNumber = computePlayVersionCodeFromEnvironment({
      'GITHUB_RUN_NUMBER': '19',
      'PLAY_VERSION_CODE_BASE': '3000',
      'PLAY_VERSION_CODE_OFFSET': '5',
    });

    expect(buildNumber, 3024);
  });

  test('uses defaults when optional environment values are blank', () {
    final buildNumber = computePlayVersionCodeFromEnvironment({
      'GITHUB_RUN_NUMBER': '19',
      'PLAY_VERSION_CODE_BASE': '',
      'PLAY_VERSION_CODE_OFFSET': '',
    });

    expect(buildNumber, 1019);
  });

  test('throws when the GitHub run number is missing', () {
    expect(
      () => computePlayVersionCodeFromEnvironment({}),
      throwsFormatException,
    );
  });
}
