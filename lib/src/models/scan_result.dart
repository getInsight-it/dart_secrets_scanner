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
