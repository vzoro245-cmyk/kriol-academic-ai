import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/update_config.dart';

class UpdateCheckResult {
  final bool isUpdateRequired;
  final UpdateConfig? config;

  UpdateCheckResult({required this.isUpdateRequired, this.config});
}

class UpdateService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<UpdateCheckResult> checkForUpdate() async {
    try {
      final doc = await _db.collection('settings').doc('android_update').get();
      
      if (!doc.exists) {
        return UpdateCheckResult(isUpdateRequired: false);
      }

      final config = UpdateConfig.fromFirestore(doc);
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_isVersionLower(currentVersion, config.minimumVersion)) {
        return UpdateCheckResult(isUpdateRequired: true, config: config);
      }

      return UpdateCheckResult(isUpdateRequired: false);
    } catch (e) {
      return UpdateCheckResult(isUpdateRequired: false);
    }
  }

  List<int> _parseVersion(String version) {
    final parts = version.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts;
  }

  bool _isVersionLower(String current, String minimum) {
    final currentParts = _parseVersion(current);
    final minimumParts = _parseVersion(minimum);

    for (int i = 0; i < 3; i++) {
      if (currentParts[i] < minimumParts[i]) return true;
      if (currentParts[i] > minimumParts[i]) return false;
    }
    return false;
  }
}
