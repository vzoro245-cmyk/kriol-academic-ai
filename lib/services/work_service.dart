import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/academic_work.dart';

class WorkService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveWork(AcademicWork work) async {
    await _db.collection('works').doc(work.id).set(work.toFirestore());
  }

  Future<void> updateWorkStatus(String workId, WorkStatus status, {String? localPath, String? fileName}) async {
    final data = {
      'status': status.name,
    };
    if (localPath != null) data['localPath'] = localPath;
    if (fileName != null) data['fileName'] = fileName;
    
    await _db.collection('works').doc(workId).update(data);
  }

  Stream<List<AcademicWork>> getUserWorks(String userId) {
    return _db
        .collection('works')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AcademicWork.fromFirestore(doc)).toList());
  }
}
