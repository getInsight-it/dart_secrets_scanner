import '../models/scan_result.dart';
import '../models/scan_target.dart';

abstract interface class LineDetector {
  ScanResult? detect(ScanTarget target);
}
