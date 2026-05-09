import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/services/auth_repository.dart';
import 'package:gas_company/features/auth/screens/login_screen.dart';
import 'package:gas_company/features/auth/screens/admin_dashboard.dart';
import 'package:gas_company/features/auth/screens/engineer_dashboard.dart';
import 'package:gas_company/features/auth/screens/store_dashboard.dart';
import 'package:gas_company/features/auth/screens/purchase_dashboard.dart';
import 'package:gas_company/core/models/user_profile.dart';
import 'package:gas_company/core/utils/enums.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  final _repo = AuthRepository();

  @override
  void initState() {
    super.initState();
    _validateSession();
  }

  Future<void> _validateSession() async {
    final session = await _repo.currentSession();
    if (session == null) {
      _goToLogin();
      return;
    }

    final userId = session.user?.id;
    if (userId == null) {
      await _repo.signOut();
      _goToLogin();
      return;
    }

    final profileMap = await _repo.fetchProfile(userId);
    if (profileMap == null) {
      // profile missing: force logout
      await _repo.signOut();
      _goToLogin();
      return;
    }

    final profile = UserProfile.fromJson(profileMap);
    // route by role
    _navigateForRole(profile);
  }

  void _goToLogin() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _navigateForRole(UserProfile profile) {
    Widget dest = const LoginScreen();
    switch (profile.role) {
      case UserRole.admin:
        dest = AdminDashboard(profile: profile);
        break;
      case UserRole.engineer:
        dest = EngineerDashboard(profile: profile);
        break;
      case UserRole.store:
        dest = StoreDashboard(profile: profile);
        break;
      case UserRole.purchase:
        dest = PurchaseDashboard(profile: profile);
        break;
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => dest));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
