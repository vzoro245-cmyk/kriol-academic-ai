import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw 'Ocorreu um erro inesperado. Tente novamente.';
    }
  }

  Future<UserCredential> signUp({
    required String name,
    required String username,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      // 1. Criar no Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = credential.user;
      if (user != null) {
        // 2. Atualizar Display Name no Auth
        await user.updateDisplayName(name);

        // 3. Criar Perfil no Firestore
        final profile = UserProfile(
          uid: user.uid,
          name: name,
          email: email.trim(),
          username: username.trim(),
          phone: phone.trim(),
          credits: 0,
          status: UserStatus.active,
          createdAt: DateTime.now(),
        );

        await _db.collection('users').doc(user.uid).set(profile.toFirestore());
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw 'Erro ao criar conta. Tente novamente.';
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Este email já está cadastrado em outra conta.';
      case 'weak-password':
        return 'A senha é muito fraca. Use pelo menos 6 caracteres.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email ou senha incorretos.';
      case 'user-disabled':
        return 'Esta conta está desativada. Entre em contato com o administrador.';
      case 'network-request-failed':
        return 'Não foi possível conectar ao servidor. Verifique sua conexão.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde.';
      case 'invalid-email':
        return 'O endereço de email não é válido.';
      default:
        return 'Ocorreu um erro: ${e.message}';
    }
  }
}
