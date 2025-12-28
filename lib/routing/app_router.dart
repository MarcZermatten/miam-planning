import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/meal_plan/presentation/screens/home_screen.dart';
import '../features/recipes/presentation/screens/recipes_screen.dart';
import '../features/recipes/presentation/screens/recipe_detail_screen.dart';
import '../features/recipes/presentation/screens/add_recipe_screen.dart';
import '../features/recipes/presentation/screens/recipe_search_screen.dart';
import '../features/recipes/presentation/screens/edit_recipe_screen.dart';
import '../features/meal_plan/presentation/screens/weekly_planner_screen.dart';
import '../features/pantry/presentation/pantry_screen.dart';
import '../features/shopping/presentation/shopping_list_screen.dart';
import '../features/family/presentation/screens/family_settings_screen.dart';
import '../features/family/presentation/screens/family_setup_screen.dart';

/// Route names
class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const familySetup = '/family-setup';
  static const home = '/home';
  static const recipes = '/recipes';
  static const recipeDetail = '/recipes/:id';
  static const editRecipe = '/recipes/:id/edit';
  static const addRecipe = '/recipes/add';
  static const searchRecipes = '/recipes/search';
  static const weeklyPlanner = '/planner';
  static const pantry = '/pantry';
  static const shopping = '/shopping';
  static const familySettings = '/family';
}

/// App router configuration
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.familySetup,
        builder: (context, state) => const FamilySetupScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.recipes,
            builder: (context, state) => const RecipesScreen(),
          ),
          GoRoute(
            path: AppRoutes.weeklyPlanner,
            builder: (context, state) => const WeeklyPlannerScreen(),
          ),
          GoRoute(
            path: AppRoutes.pantry,
            builder: (context, state) => const PantryScreen(),
          ),
          GoRoute(
            path: AppRoutes.shopping,
            builder: (context, state) => const ShoppingListScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.addRecipe,
        builder: (context, state) {
          final initialUrl = state.uri.queryParameters['url'];
          return AddRecipeScreen(initialUrl: initialUrl);
        },
      ),
      GoRoute(
        path: AppRoutes.searchRecipes,
        builder: (context, state) => const RecipeSearchScreen(),
      ),
      GoRoute(
        path: AppRoutes.recipeDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return RecipeDetailScreen(recipeId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.editRecipe,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EditRecipeScreen(recipeId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.familySettings,
        builder: (context, state) => const FamilySettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page non trouvee: ${state.uri}'),
      ),
    ),
  );
});

/// Main shell with bottom navigation
class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (index) => _onItemTapped(index, context),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Recettes',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Planning',
          ),
          NavigationDestination(
            icon: Icon(Icons.kitchen_outlined),
            selectedIcon: Icon(Icons.kitchen),
            label: 'Stock',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Courses',
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutes.home)) return 0;
    if (location.startsWith(AppRoutes.recipes)) return 1;
    if (location.startsWith(AppRoutes.weeklyPlanner)) return 2;
    if (location.startsWith(AppRoutes.pantry)) return 3;
    if (location.startsWith(AppRoutes.shopping)) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        context.go(AppRoutes.recipes);
        break;
      case 2:
        context.go(AppRoutes.weeklyPlanner);
        break;
      case 3:
        context.go(AppRoutes.pantry);
        break;
      case 4:
        context.go(AppRoutes.shopping);
        break;
    }
  }
}
