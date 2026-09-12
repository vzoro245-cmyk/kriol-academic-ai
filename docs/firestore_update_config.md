# Configuração de Atualização Android

Este documento descreve como configurar o sistema de atualização obrigatória própria (fora da Play Store) para o aplicativo Kriol Academic AI.

## Localização no Firestore

O aplicativo consulta o seguinte documento para verificar se uma atualização é necessária:

- **Coleção:** `settings`
- **ID do Documento:** `android_update`

## Estrutura do Documento

Crie o documento com os seguintes campos (todos do tipo `string`, exceto onde indicado):

| Campo | Tipo | Descrição | Exemplo |
| :--- | :--- | :--- | :--- |
| `latestVersion` | String | A versão mais recente disponível. | `"1.1.0"` |
| `minimumVersion` | String | A versão mínima exigida para que o app funcione. | `"1.1.0"` |
| `updateUrl` | String | Link direto para o download do novo arquivo .apk. | `"https://github.com/.../app-release.apk"` |
| `message` | String | Mensagem personalizada exibida na tela de bloqueio. | `"Nova versão disponível com melhorias críticas."` |

## Como Forçar a Atualização

O aplicativo utiliza uma lógica de comparação semântica (X.Y.Z).

1. No Firebase Console, vá para **Firestore Database**.
2. No documento `settings/android_update`, altere o campo `minimumVersion`.
3. Se a versão instalada no celular do usuário for **menor** que a `minimumVersion`, o aplicativo será bloqueado e redirecionado para a tela de atualização.

## Regras de Segurança (Firestore Rules)

O acesso à coleção `settings` deve ser permitido apenas para leitura por usuários autenticados:

```javascript
match /settings/{doc} {
  allow read: if request.auth != null;
  allow write: if false;
}
```

## Hospedagem do APK

Como o aplicativo é distribuído fora da Play Store, o arquivo `.apk` deve estar hospedado em um local público e seguro (HTTPS). Recomenda-se o uso do **GitHub Releases** ou **Firebase Storage** (com link público).
