import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'scanner_config.dart';

class ScanResult {
  final String filePath;
  final int lineNumber;
  final String message;

  const ScanResult({
    required this.filePath,
    required this.lineNumber,
    required this.message,
  });

  @override
  String toString() => '$message in $filePath:$lineNumber';
}

class Scanner {
  final Directory root;
  final ScannerConfig config;

  Scanner({
    Directory? root,
    ScannerConfig? config,
  })  : root = root ?? Directory.current,
        config = config ?? ScannerConfig.defaults();

  static final _supportedExtensions = <String>{
    '.dart',
    '.json',
    '.yaml',
    '.yml',
    '.properties',
    '.java',
    '.kt',
    '.swift',
    '.gradle',
    '.xml',
    '.env',
    '.plist',
    '.sh',
    '.ps1',
    '.txt',
  };

  static final _contextExtensions = <String>{
    '.json',
    '.yaml',
    '.yml',
    '.env',
    '.plist',
  };

  static final RegExp _variablePattern = RegExp(
    r'''(const|final|var|String)\s+([A-Za-z0-9_]+)\s*=\s*["']([A-Za-z0-9&@#%^*()_\-+!?<>~`{}|[\]:;./]{8,})["']''',
  );

  static final RegExp _alphanumericPattern =
      RegExp(r'(?=.*[a-zA-Z])(?=.*\d)[A-Za-z0-9&@#%^*()_\-+!?<>~`{}|[\]:;./]{8,}');

  static final RegExp _contextKeyValuePattern = RegExp(
    r'''["']?([\w\-.]+)["']?\s*[:=]\s*["']?([A-Za-z0-9+=/_\-]{8,})["']?''',
  );

  static final List<_SecretPattern> _secretPatterns = [
    _SecretPattern('GitLab Personal Access Token', RegExp(r'glpat-[0-9a-zA-Z_\-]{20}')),
    _SecretPattern('GitHub Personal Access Token', RegExp(r'ghp_[0-9a-zA-Z]{36}')),
    _SecretPattern('GitHub OAuth Token', RegExp(r'gho_[0-9a-zA-Z]{36}')),
    _SecretPattern('GitHub App Token', RegExp(r'(ghu|ghs)_[0-9a-zA-Z]{36}')),
    _SecretPattern('AWS Access Key', RegExp(r'AKIA[0-9A-Z]{16}')),
    _SecretPattern('Stripe Live API Key', RegExp(r'sk_live_[0-9a-zA-Z]{24}')),
    _SecretPattern('Google API Key', RegExp(r'AIza[0-9A-Za-z\-_]{35}')),
    _SecretPattern(
        'URL with embedded credentials',
        RegExp(r'[a-zA-Z]{3,10}://[^:$@\n/]{3,20}:[^:$@\n/]{3,40}@[^ \n]+')),
  ];

  Future<List<ScanResult>> scan() async {
    final files = _collectFiles();
    final results = <ScanResult>[];

    for (final entity in files) {
      if (entity is! File) {
        continue;
      }
      final relativePath = path.relative(entity.path, from: root.path);
      if (config.matchesExcludedPath(relativePath)) {
        continue;
      }
      results.addAll(await _scanFile(entity));
    }

    return results;
  }

  List<FileSystemEntity> _collectFiles() {
    return root.listSync(recursive: true, followLinks: false).where((entity) {
      if (entity is! File) return false;
      final baseName = path.basename(entity.path);
      if (baseName == scannerConfigFileName ||
          baseName.endsWith('.yaml.example')) {
        return false;
      }
      final extension = path.extension(entity.path).toLowerCase();
      return _supportedExtensions.contains(extension);
    }).toList();
  }

  Future<List<ScanResult>> _scanFile(File file) async {
    final content = await file.readAsLines();
    final relativePath = path.relative(file.path, from: root.path);
    final extension = path.extension(file.path).toLowerCase();
    final isContextFile = _contextExtensions.contains(extension);

    final matches = <ScanResult>[];

    for (var lineNumber = 0; lineNumber < content.length; lineNumber++) {
      final line = content[lineNumber].trim();
      if (line.isEmpty) {
        continue;
      }

      final variableResult = _matchVariableDeclaration(line, relativePath, lineNumber + 1);
      if (variableResult != null) {
        matches.add(variableResult);
        continue;
      }

      for (final secret in _secretPatterns) {
        if (secret.pattern.hasMatch(line)) {
          matches.add(ScanResult(
            filePath: relativePath,
            lineNumber: lineNumber + 1,
            message: 'Found ${secret.description}',
          ));
          break;
        }
      }

      if (isContextFile) {
        final contextResult =
            _matchContextualSecret(line, relativePath, lineNumber + 1);
        if (contextResult != null) {
          matches.add(contextResult);
        }
      }
    }

    return matches;
  }

  ScanResult? _matchVariableDeclaration(
      String line, String relativePath, int lineNumber) {
    final match = _variablePattern.firstMatch(line);
    if (match == null) {
      return null;
    }

    final variableName = match.group(2);
    final variableValue = match.group(3);
    if (variableName == null ||
        variableValue == null ||
        !_alphanumericPattern.hasMatch(variableValue)) {
      return null;
    }

    if (config.matchesExcludedVariable(variableName)) {
      return null;
    }

    return ScanResult(
      filePath: relativePath,
      lineNumber: lineNumber,
      message:
          'Found hardcoded variable: "$variableName" with value: "$variableValue"',
    );
  }

  ScanResult? _matchContextualSecret(
      String line, String relativePath, int lineNumber) {
    final match = _contextKeyValuePattern.firstMatch(line);
    if (match == null) {
      return null;
    }

    final key = match.group(1);
    final value = match.group(2);
    if (key == null || value == null) {
      return null;
    }

    final sanitizedKey = key.toLowerCase();
    final hasKeyword = config.contextKeywords
        .any((keyword) => sanitizedKey.contains(keyword.toLowerCase()));
    if (!hasKeyword) {
      return null;
    }

    if (!_alphanumericPattern.hasMatch(value)) {
      return null;
    }

    return ScanResult(
      filePath: relativePath,
      lineNumber: lineNumber,
      message:
          'Found MASVS-relevant config key "$key" with hardcoded value: "$value"',
    );
  }
}

class _SecretPattern {
  final String description;
  final RegExp pattern;

  const _SecretPattern(this.description, this.pattern);
}
