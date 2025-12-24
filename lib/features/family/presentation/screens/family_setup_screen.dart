import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../routing/app_router.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/family_repository.dart';

class FamilySetupScreen extends ConsumerStatefulWidget {
  const FamilySetupScreen({super.key});

  @override
  ConsumerState<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends ConsumerState<FamilySetupScreen> {
  bool _isCreating = true;
  bool _isLoading = false;
  String? _errorMessage;

  final _familyNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  @override
  void dispose() {
    _familyNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _createFamily() async {
    if (_familyNameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Entrez un nom pour votre famille');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('Non connecte');

      final familyRepo = ref.read(familyRepositoryProvider);
      final family = await familyRepo.createFamily(
        name: _familyNameController.text.trim(),
        odauyX6H2Z: user.uid,
        userName: user.displayName ?? 'Membre',
      );

      if (mounted) {
        ref.read(currentFamilyIdProvider.notifier).state = family.id;
        context.go(AppRoutes.home);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Erreur lors de la creation: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinFamily() async {
    final code = _inviteCodeController.text.trim().toUpperCase();
    if (code.isEmpty || code.length != 6) {
      setState(() => _errorMessage = 'Entrez un code a 6 caracteres');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('Non connecte');

      final familyRepo = ref.read(familyRepositoryProvider);
      final family = await familyRepo.joinFamily(
        inviteCode: code,
        odauyX6H2Z: user.uid,
        userName: user.displayName ?? 'Membre',
      );

      if (family == null) {
        setState(() => _errorMessage = 'Code invalide ou famille introuvable');
        return;
      }

      if (mounted) {
        ref.read(currentFamilyIdProvider.notifier).state = family.id;
        context.go(AppRoutes.home);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Erreur: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              // Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.family_restroom,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              // Title
              const Text(
                'Configurez votre famille',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Creez une nouvelle famille ou rejoignez-en une existante',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),

              // Toggle tabs
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTab('Creer', _isCreating, () {
                        setState(() => _isCreating = true);
                      }),
                    ),
                    Expanded(
                      child: _buildTab('Rejoindre', !_isCreating, () {
                        setState(() => _isCreating = false);
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Form
              if (_isCreating) ...[
                TextFormField(
                  controller: _familyNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la famille',
                    hintText: 'Ex: Famille Dupont',
                    prefixIcon: Icon(Icons.edit),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Un code d\'invitation sera genere pour inviter d\'autres membres.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ] else ...[
                TextFormField(
                  controller: _inviteCodeController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Code d\'invitation',
                    hintText: 'Ex: ABC123',
                    prefixIcon: Icon(Icons.vpn_key),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Demandez le code a un membre de la famille que vous souhaitez rejoindre.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Submit button
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (_isCreating ? _createFamily : _joinFamily),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isCreating ? 'Creer ma famille' : 'Rejoindre'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
