import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../providers/auth_provider.dart';

/// Profile screen — displays user info and allows editing.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final role = ref.watch(currentUserRoleProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () async {
              await ref.read(logoutProvider).call();
            },
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(
              child: Text('Not signed in', style: AppTextStyles.body),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ─── Avatar ───
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.primaryDim,
                    backgroundImage: user.avatarUrl != null
                        ? NetworkImage(user.avatarUrl!)
                        : null,
                    child: user.avatarUrl == null
                        ? Text(
                            user.fullName.isNotEmpty
                                ? user.fullName[0].toUpperCase()
                                : '?',
                            style: AppTextStyles.kpiValue.copyWith(
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                // ─── Name & Role ───
                Text(user.fullName, style: AppTextStyles.pageTitle),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDim,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (role ?? 'user').toUpperCase(),
                    style: AppTextStyles.chipText.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ─── Profile Details ───
                AppCard(
                  child: Column(
                    children: [
                      _ProfileRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: user.email ?? '—',
                      ),
                      const Divider(height: 24),
                      _ProfileRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: user.phone ?? 'Not set',
                      ),
                      const Divider(height: 24),
                      _ProfileRow(
                        icon: Icons.badge_outlined,
                        label: 'Employee ID',
                        value: user.employeeId ?? 'Not set',
                      ),
                      const Divider(height: 24),
                      _ProfileRow(
                        icon: Icons.work_outline_rounded,
                        label: 'Designation',
                        value: user.designation ?? 'Not set',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Text(
            'Error: $e',
            style: AppTextStyles.body.copyWith(color: AppColors.danger),
          ),
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.bodySmall),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.body),
            ],
          ),
        ),
      ],
    );
  }
}
