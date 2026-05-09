import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/features/auth/splash_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/core/services/supabase_service.dart';
import 'package:gas_company/core/utils/enums.dart';
import 'package:gas_company/features/auth/providers/auth_provider.dart';
import 'package:gas_company/features/auth/screens/login_screen.dart';
import 'package:gas_company/features/auth/screens/admin_dashboard.dart';
import 'package:gas_company/features/auth/screens/engineer_dashboard.dart';
import 'package:gas_company/features/auth/screens/store_dashboard.dart';
import 'package:gas_company/features/auth/screens/purchase_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load keys from dart-define or .env file, then initialize Supabase.
  await SupabaseConfig.ensureLoaded();
  await initSupabaseAndMonitor(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  runApp(const ProviderScope(child: BuildFlowApp()));
}

class BuildFlowApp extends StatelessWidget {
  const BuildFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BuildFlow Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}

/// Auth gate: routes to login or role-based dashboard
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (state) {
        if (state.session == null) {
          return const LoginScreen();
        }
        return const _RoleRouter();
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => const LoginScreen(),
    );
  }
}

/// Routes to the correct dashboard based on user role
class _RoleRouter extends ConsumerWidget {
  const _RoleRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);

    return profile.when(
      data: (user) {
        if (user == null) {
          return const LoginScreen();
        }

        switch (user.role) {
          case UserRole.admin:
            return AdminDashboard(profile: user);
          case UserRole.engineer:
            return EngineerDashboard(profile: user);
          case UserRole.store:
            return StoreDashboard(profile: user);
          case UserRole.purchase:
            return PurchaseDashboard(profile: user);
          default:
            return const LoginScreen();
        }
      },
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Loading profile...',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Error: $e',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(authNotifierProvider.notifier).signOut(),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
