import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Shimmer loading skeleton (UI-003 — every screen must have loading state).
class LoadingSkeleton extends StatefulWidget {
  final int itemCount;

  const LoadingSkeleton({super.key, this.itemCount = 5});

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: widget.itemCount,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _SkeletonCard(
              opacity: (0.3 + 0.4 * (((_controller.value + index * 0.1) % 1.0))),
            );
          },
        );
      },
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double opacity;

  const _SkeletonCard({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.3, 0.7),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title placeholder
            Container(
              width: 180,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            // Subtitle placeholder
            Container(
              width: 120,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            // Content placeholder
            Container(
              width: double.infinity,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
