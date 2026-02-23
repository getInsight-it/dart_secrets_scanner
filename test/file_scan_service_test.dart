import 'dart:io';

import 'package:test/test.dart';

import 'package:dart_secrets_scanner/src/detectors/line_detector.dart';
import 'package:dart_secrets_scanner/src/models/scan_result.dart';
import 'package:dart_secrets_scanner/src/models/scan_target.dart';
import 'package:dart_secrets_scanner/src/services/file_scan_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('file_scan_service_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('stops detector chain after first match for a line', () async {
    final file = File('${tempDir.path}/sample.dart');
    await file.writeAsString('const apiKey = "Abc12345";');

    final firstDetector = _FixedDetector('first');
    final secondDetector = _FixedDetector('second');
    final service = FileScanService([firstDetector, secondDetector]);

    final results = await service.scanFile(file, tempDir);

    expect(results, hasLength(1));
    expect(results.single.message, equals('first'));
    expect(secondDetector.calls, equals(0));
  });
}

class _FixedDetector implements LineDetector {
  _FixedDetector(this.message);

  final String message;
  int calls = 0;

  @override
  ScanResult? detect(ScanTarget target) {
    calls += 1;
    return ScanResult(
      filePath: target.filePath,
      lineNumber: target.lineNumber,
      message: message,
    );
  }
}
