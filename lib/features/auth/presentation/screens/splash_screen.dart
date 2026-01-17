import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../routing/app_router.dart';
import '../../../family/data/family_repository.dart';
import '../../data/auth_repository.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // Wait for Firebase Auth to restore session (not just the stream value)
    final auth = ref.read(firebaseAuthProvider);
    final user = auth.currentUser ?? await auth.authStateChanges().first;

    if (user == null) {
      context.go(AppRoutes.login);
      return;
    }

    // User is logged in - check if we have a saved family
    final savedFamilyId = ref.read(currentFamilyIdProvider);

    if (savedFamilyId != null) {
      // Verify the family still exists and user is still a member
      final family = await ref.read(familyRepositoryProvider).watchFamily(savedFamilyId).first;
      if (family != null) {
        // Family exists, go to home
        if (mounted) context.go(AppRoutes.home);
        return;
      } else {
        // Family was deleted, clear the saved ID
        ref.read(currentFamilyIdProvider.notifier).clearFamilyId();
      }
    }

    // No saved family or it was invalid - check user's families
    try {
      final familyRepo = ref.read(familyRepositoryProvider);
      var families = await familyRepo
          .getUserFamilies(user.uid)
          .first
          .timeout(const Duration(seconds: 10));

      // If no families found in user document, try to recover from membership data
      if (families.isEmpty) {
        print('No families in user document, attempting recovery...');
        families = await familyRepo.recoverUserFamilies(user.uid);
      }

      if (families.isNotEmpty) {
        // Auto-select first family
        ref.read(currentFamilyIdProvider.notifier).setFamilyId(families.first.id);
        if (mounted) context.go(AppRoutes.home);
      } else {
        // No families - go to family setup
        if (mounted) context.go(AppRoutes.familySetup);
      }
    } catch (e) {
      // Timeout or error - go to family setup
      print('Error loading families: $e');
      if (mounted) context.go(AppRoutes.familySetup);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App icon
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/popote_logo.png',
                width: 120,
                height: 120,
              ),
            ),
            const SizedBox(height: 24),
            // App name
            const Text(
              'Popote',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Planifiez les repas en famille',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
