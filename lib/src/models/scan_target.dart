class ScanTarget {
  final String filePath;
  final int lineNumber;
  final String line;
  final bool isContextFile;

  const ScanTarget({
    required this.filePath,
    required this.lineNumber,
    required this.line,
    required this.isContextFile,
  });
}
