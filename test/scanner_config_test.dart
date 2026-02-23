import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import 'package:dart_secrets_scanner/src/config/scanner_config.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('scanner_config_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('loads defaults when config file is missing', () async {
    final config = await ScannerConfig.load(root: tempDir);

    expect(config.contextKeywords, contains('token'));
    expect(config.matchesExcludedPath('test/a.dart'), isTrue);
    expect(config.matchesExcludedVariable('format'), isTrue);
  });

  test('merges custom config values', () async {
    final configFile = File(path.join(tempDir.path, scannerConfigFileName));
    await configFile.writeAsString('''
scanner:
  exclude_variable_names:
    - customName
  exclude_paths:
    - generated/output
  context_keywords:
    - cert_pin
''');

    final config = await ScannerConfig.load(root: tempDir);

    expect(config.matchesExcludedVariable('customName'), isTrue);
    expect(config.matchesExcludedPath('lib/generated/output/a.dart'), isTrue);
    expect(config.contextKeywords, contains('cert_pin'));
  });
}
