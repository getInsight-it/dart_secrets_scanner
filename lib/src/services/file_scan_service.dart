import 'dart:io';

import 'package:path/path.dart' as path;

import '../detectors/context_secret_detector.dart';
import '../detectors/line_detector.dart';
import '../models/scan_result.dart';
import '../models/scan_target.dart';

class FileScanService {
  FileScanService(this._detectors);

  final List<LineDetector> _detectors;

  Future<List<ScanResult>> scanFile(File file, Directory root) async {
    final lines = await file.readAsLines();
    final relativePath = path.relative(file.path, from: root.path);
    final extension = path.extension(file.path).toLowerCase();
    final isContextFile = ContextSecretDetector.isContextExtension(extension);

    final results = <ScanResult>[];

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trim();
      if (line.isEmpty) {
        continue;
      }

      final target = ScanTarget(
        filePath: relativePath,
        lineNumber: index + 1,
        line: line,
        isContextFile: isContextFile,
      );

      for (final detector in _detectors) {
        final result = detector.detect(target);
        if (result != null) {
          results.add(result);
          break;
        }
      }
    }

    return results;
  }
}
