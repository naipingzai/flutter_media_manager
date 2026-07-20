/// Design system for AdvanceMediaKB.
///
/// Provides consistent spacing, radius, sizing, typography, and color
/// tokens used across all UI surfaces.
library;

import 'package:flutter/material.dart';

// ─── Spacing ───────────────────────────────────────────────────────────
class AppSpacing {
  AppSpacing._();
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

// ─── Radius ────────────────────────────────────────────────────────────
class AppRadius {
  AppRadius._();
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 28.0;
  static const double full = 999.0;
}

// ─── Icon / Element sizing ─────────────────────────────────────────────
class AppSize {
  AppSize._();
  static const double borderWidth = 1.0;
  static const double borderWidthStrong = 2.0;
  static const double iconXs = 14.0;
  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
  static const double iconXl = 32.0;
  static const double iconXxl = 48.0;
  static const double iconHero = 64.0;
  static const double touchTarget = 48.0;
  static const double thumbnailGrid = 120.0;
  static const double cardMinHeight = 80.0;

  // Backward-compatible aliases (deprecated – use the new names above)
  @Deprecated('Use iconSm instead')
  static const double iconSmall = iconSm;
  @Deprecated('Use iconMd instead')
  static const double iconMedium = iconLg;
  @Deprecated('Use iconXl instead')
  static const double iconLarge = iconXl;
  @Deprecated('Use iconXxl instead')
  static const double iconXLarge = iconXxl;
  @Deprecated('Use iconXxl instead')
  static const double iconXl_ = iconXxl;
  @Deprecated('Use touchTarget instead')
  static const double touchTargetMin = touchTarget;
  @Deprecated('Use borderWidth instead')
  static const double borderWidthDefault = borderWidth;
  @Deprecated('Use iconXl instead')
  static const double iconXl2 = iconXxl;
}

// ─── Elevation ─────────────────────────────────────────────────────────
class AppElevation {
  AppElevation._();
  static const double none = 0.0;
  static const double low = 1.0;
  static const double medium = 3.0;
  static const double high = 6.0;
}

// ─── Animation durations ───────────────────────────────────────────────
class AppAnimation {
  AppAnimation._();
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration thumbnailScale = Duration(milliseconds: 200);
  @Deprecated('Use thumbnailScale instead')
  static const Duration thumbnailScaleIn = thumbnailScale;
}

// ─── Typography ────────────────────────────────────────────────────────
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle hero = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static const TextStyle title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );
}

// ─── Breadcrumb ────────────────────────────────────────────────────────

class BreadcrumbNode {
  final String label;
  final String id;
  final IconData? icon;
  final VoidCallback? onTap;

  const BreadcrumbNode({
    required this.label,
    required this.id,
    this.icon,
    this.onTap,
  });
}

class BreadcrumbBar extends StatelessWidget {
  final List<BreadcrumbNode> nodes;
  final ValueChanged<int>? onTap;

  const BreadcrumbBar({super.key, required this.nodes, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < nodes.length; i++) ...[
          if (i > 0) const Icon(Icons.chevron_right, size: 18),
          InkWell(
            onTap: () {
              nodes[i].onTap?.call();
              onTap?.call(i);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (nodes[i].icon != null) ...[
                    Icon(nodes[i].icon, size: 18),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    nodes[i].label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Formats a media duration in seconds to a readable string.
String formatDuration(int seconds) {
  if (seconds < 60) return '0:${seconds.toString().padLeft(2, '0')}';
  if (seconds < 3600) {
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
