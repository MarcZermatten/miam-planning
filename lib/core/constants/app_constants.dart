/// App-wide constants
class AppConstants {
  // App info
  static const String appName = 'MiamPlanning';
  static const String appVersion = '1.0.0';

  // Meal types (Swiss French terminology)
  // Primary meals: lunch (diner) and dinner (souper)
  static const List<String> defaultMealTypes = [
    'breakfast',
    'lunch',
    'dinner',
    'snack',
  ];

  // Primary meals for planning (diner + souper)
  static const List<String> primaryMealTypes = [
    'lunch',
    'dinner',
  ];

  // Meal labels (Swiss French: diner = midi, souper = soir)
  static const Map<String, String> mealLabels = {
    'breakfast': 'Petit-dejeuner',
    'lunch': 'Diner',
    'dinner': 'Souper',
    'snack': 'Gouter',
  };

  // Days of week (French)
  static const List<String> weekDays = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  // Difficulty levels
  static const Map<int, String> difficultyLabels = {
    1: 'Tres facile',
    2: 'Facile',
    3: 'Moyen',
    4: 'Difficile',
    5: 'Expert',
  };

  // Common allergies
  static const List<String> commonAllergies = [
    'gluten',
    'lactose',
    'oeufs',
    'arachides',
    'fruits_a_coque',
    'soja',
    'poisson',
    'crustaces',
    'celeri',
    'moutarde',
    'sesame',
    'sulfites',
  ];

  // Common dietary restrictions
  static const List<String> dietaryRestrictions = [
    'vegetarien',
    'vegan',
    'sans_porc',
    'halal',
    'kasher',
    'sans_sucre',
    'low_carb',
  ];

  // Pantry staples (ignored in ingredient search)
  static const List<String> pantryStaples = [
    'sel',
    'poivre',
    'huile',
    'huile d\'olive',
    'beurre',
    'eau',
    'sucre',
    'farine',
    'vinaigre',
    'ail',
    'oignon',
  ];

  // Time thresholds (minutes)
  static const int quickMealTime = 20;
  static const int mediumMealTime = 45;
  static const int longMealTime = 90;

  // API
  static const String spoonacularBaseUrl = 'https://api.spoonacular.com';
}
