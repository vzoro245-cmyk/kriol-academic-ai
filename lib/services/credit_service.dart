import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import '../core/config/env_config.dart';
import '../models/credit.dart';

class CreditService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Dio _dio = Dio(BaseOptions(baseUrl: '${EnvConfig.apiUrl}/api'));

  Stream<int> getUserCredits(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        return (data['credits'] as num?)?.toInt() ?? 0;
      }
      return 0;
    });
  }

  Stream<List<CreditTransaction>> getCreditHistory(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final history = data['creditsHistory'] as List<dynamic>?;
        if (history != null) {
          // Sort by date descending
          final transactions = history.map((e) => CreditTransaction.fromMap(e, '')).toList();
          transactions.sort((a, b) => b.date.compareTo(a.date));
          return transactions;
        }
      }
      return [];
    });
  }

  Future<List<CreditPackage>> getCreditPackages() async {
    final query = await _db.collection('credit_packages').get();
    return query.docs.map((doc) => CreditPackage.fromFirestore(doc)).toList();
  }

  Future<void> useCredit(String userId, String workTitle) async {
    try {
      final response = await _dio.post('/credits/use', data: {
        'userId': userId,
        'description': 'Geração de trabalho: $workTitle',
      });

      if (response.statusCode != 200) {
        throw response.data['error'] ?? 'Falha ao processar crédito.';
      }
    } on DioException catch (e) {
      throw e.response?.data['error'] ?? 'Erro de conexão com o servidor de créditos.';
    }
  }

  Future<int> redeemCode(String userId, String code) async {
    final cleanCode = code.toUpperCase().trim();
    if (cleanCode.isEmpty) throw 'O código não pode estar vazio.';

    final codeRef = _db.collection('credit_codes').doc(cleanCode);
    final userRef = _db.collection('users').doc(userId);

    try {
      return await _db.runTransaction((transaction) async {
        final codeSnap = await transaction.get(codeRef);

        if (!codeSnap.exists) {
          throw 'Código inválido ou inexistente.';
        }

        final data = codeSnap.data();
        if (data == null) throw 'Erro ao ler dados do código.';
        
        if (data['status'] != 'available') {
          throw 'Este código já foi utilizado ou está indisponível.';
        }

        final creditsValue = data['credits'];
        final int creditsToAdd = (creditsValue is num) ? creditsValue.toInt() : 0;
        
        if (creditsToAdd <= 0) {
          throw 'Este código não possui créditos válidos.';
        }

        final userSnap = await transaction.get(userRef);
        if (!userSnap.exists) {
          throw 'Perfil de usuário não encontrado.';
        }

        final userData = userSnap.data();
        if (userData == null) throw 'Erro ao ler dados do usuário.';
        
        final userCreditsValue = userData['credits'];
        final int currentCredits = (userCreditsValue is num) ? userCreditsValue.toInt() : 0;

        // 1. Atualizar o status do código
        transaction.update(codeRef, {
          'status': 'used',
          'usedBy': userId,
          'usedAt': FieldValue.serverTimestamp(),
        });

        // 2. Adicionar créditos ao usuário e registrar no histórico interno do documento
        transaction.update(userRef, {
          'credits': currentCredits + creditsToAdd,
          'creditsHistory': FieldValue.arrayUnion([
            {
              'type': 'purchase',
              'amount': creditsToAdd,
              'date': Timestamp.now(), 
              'description': 'Resgate de código: $cleanCode',
            }
          ]),
        });

        // 3. Registrar na coleção independente 'credit_transactions' para maior segurança/auditoria
        final newTransactionRef = _db.collection('credit_transactions').doc();
        transaction.set(newTransactionRef, {
          'userId': userId,
          'type': 'redeem',
          'amount': creditsToAdd,
          'code': cleanCode,
          'date': FieldValue.serverTimestamp(),
          'status': 'completed'
        });

        return creditsToAdd;
      });
    } catch (e) {
      // Repassar erro para a UI
      rethrow;
    }
  }
}
