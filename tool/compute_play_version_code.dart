import 'dart:io';

import 'package:bookbeam/services/play_version_code.dart';

void main() {
  final buildNumber =
      computePlayVersionCodeFromEnvironment(Platform.environment);
  stdout.writeln(buildNumber);
}
