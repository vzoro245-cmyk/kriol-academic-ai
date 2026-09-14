import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/academic_work.dart';

class WorkService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Novo path: /users/{uid}/works/{workId}
  CollectionReference _getWorkCollection(String userId) {
    return _db.collection('users').doc(userId).collection('works');
  }

  Future<void> saveWork(AcademicWork work) async {
    await _getWorkCollection(work.userId).doc(work.id).set(work.toFirestore());
  }

  Future<void> updateWorkStatus(String workId, WorkStatus status, {
    String? localPath, 
    String? localUri,
    String? fileName,
    String? norm,
    int? pages,
    String? userId, // Necessário para o novo path
  }) async {
    if (userId == null) throw 'UserId is required for the new Firestore path structure';

    final data = <String, dynamic>{
      'status': status.name,
    };
    if (localPath != null) data['localPath'] = localPath;
    if (localUri != null) data['localUri'] = localUri;
    if (fileName != null) data['fileName'] = fileName;
    if (norm != null) data['norm'] = norm;
    if (pages != null) data['pageCount'] = pages;
    if (status == WorkStatus.completed) {
      data['savedAt'] = FieldValue.serverTimestamp();
    }
    
    await _getWorkCollection(userId).doc(workId).update(data);
  }

  Stream<List<AcademicWork>> getUserWorks(String userId) {
    return _getWorkCollection(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AcademicWork.fromFirestore(doc)).toList());
  }
}
