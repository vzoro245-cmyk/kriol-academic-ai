const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

exports.activateCreditCode = functions.https.onCall(async (data, context) => {
  // 1. Verificar autenticação
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "O usuário deve estar logado para ativar um código."
    );
  }

  const uid = context.auth.uid;
  const rawCode = data.code;

  if (!rawCode || typeof rawCode !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "O código de recarga é obrigatório."
    );
  }

  // 2. Normalizar código
  const normalizedCode = rawCode.trim().toUpperCase();

  try {
    return await db.runTransaction(async (transaction) => {
      // 3. Buscar o código
      const codeQuery = await db
        .collection("credit_codes")
        .where("code", "==", normalizedCode)
        .limit(1)
        .get();

      if (codeQuery.empty) {
        throw new functions.https.HttpsError(
          "not-found",
          "Este código de recarga não existe."
        );
      }

      const codeDoc = codeQuery.docs[0];
      const codeData = codeDoc.data();

      // 4. Verificar se o código já foi usado
      if (codeData.status === "used") {
        throw new functions.https.HttpsError(
          "already-exists",
          "Este código de recarga já foi utilizado."
        );
      }

      // 5. Verificar o perfil do usuário e status
      const userRef = db.collection("users").doc(uid);
      const userDoc = await transaction.get(userRef);

      if (!userDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Perfil do usuário não encontrado."
        );
      }

      const userData = userDoc.data();
      if (userData.status === "disabled") {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Esta conta está desativada. Entre em contato com o administrador."
        );
      }

      // 6. Executar atualizações atômicas
      const currentCredits = Number(userData.credits) || 0;
      const creditsToAdd = Number(codeData.credits) || 0;
      const newCredits = currentCredits + creditsToAdd;

      // Atualizar saldo do usuário
      transaction.update(userRef, {
        credits: newCredits,
      });

      // Marcar código como usado
      transaction.update(codeDoc.ref, {
        status: "used",
        usedAt: admin.firestore.FieldValue.serverTimestamp(),
        usedBy: uid,
      });

      return {
        success: true,
        creditsAdded: creditsToAdd,
        newBalance: newCredits,
      };
    });
  } catch (error) {
    console.error("Erro na ativação do código:", error);
    // Se for um HttpsError, repassar
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    // Caso contrário, erro genérico
    throw new functions.https.HttpsError(
      "internal",
      error.message || "Ocorreu um erro interno ao processar a recarga."
    );
  }
});
