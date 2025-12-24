/// Google OAuth Client IDs
///
/// Ces IDs doivent être créés dans Google Cloud Console :
/// https://console.cloud.google.com/apis/credentials?project=miam-planning-app
///
/// Pour Windows : Créer un "ID client OAuth" de type "Application de bureau"
/// Pour Android : Utilise automatiquement le SHA-1 configuré dans Firebase

class GoogleAuthConfig {
  // Client ID Windows Desktop (créé dans Google Cloud Console)
  static const String windowsClientId =
      '468767635530-4pso8pv36kgvqrq1fpnnijnmr8m1s39m.apps.googleusercontent.com';

  // Web client ID (depuis Firebase Console > Authentication > Google)
  static const String webClientId =
      '468767635530-p7l2c4g38adq6sbjurr8asc4elejpo5g.apps.googleusercontent.com';
}
