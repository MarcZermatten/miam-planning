/// Google OAuth Client IDs
///
/// Ces IDs doivent être créés dans Google Cloud Console :
/// https://console.cloud.google.com/apis/credentials?project=miam-planning-app
///
/// Pour Windows : Créer un "ID client OAuth" de type "Application de bureau"
/// Pour Android : Utilise automatiquement le SHA-1 configuré dans Firebase

class GoogleAuthConfig {
  // TODO: Remplacer par ton Client ID Windows depuis Google Cloud Console
  // Format: XXXXX.apps.googleusercontent.com
  static const String windowsClientId = '';

  // Web client ID (depuis Firebase Console > Authentication > Google > Web client ID)
  // Nécessaire pour obtenir l'idToken sur certaines plateformes
  static const String webClientId = '';
}
