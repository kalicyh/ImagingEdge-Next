import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:imagingedge_next/l10n/app_localizations.dart';

class FluidDock extends StatelessWidget {
  const FluidDock({super.key, required this.currentRoute});

  final String? currentRoute;

  static final _items = <_DockDestination>[
    _DockDestination(route: '/', icon: Icons.wifi_tethering, labelKey: 'dockConnection'),
    _DockDestination(route: '/images', icon: Icons.photo_library, labelKey: 'dockImages'),
    _DockDestination(route: '/gallery', icon: Icons.collections, labelKey: 'dockGallery'),
    _DockDestination(route: '/settings', icon: Icons.settings, labelKey: 'dockSettings'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SizedBox(
        height: 64,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(theme.brightness == Brightness.dark ? 0.32 : 0.48),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(theme.brightness == Brightness.dark ? 0.08 : 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / _items.length;
                  return Row(
                    children: _items.map((destination) {
                      final isActive = destination.route == currentRoute;
                      return SizedBox(
                        width: itemWidth,
                        child: _DockButton(
                          destination: destination,
                          isActive: isActive,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.destination,
    required this.isActive,
  });

  final _DockDestination destination;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final label = switch (destination.labelKey) {
      'dockConnection' => l10n.dockConnection,
      'dockImages' => l10n.dockImages,
      'dockGallery' => l10n.dockGallery,
      'dockSettings' => l10n.dockSettings,
      _ => destination.labelKey,
    };

    final activeColor = theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.onSurfaceVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        final current = ModalRoute.of(context)?.settings.name;
        if (current == destination.route) return;
        Navigator.of(context).pushReplacementNamed(destination.route);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              destination.icon,
              size: 22,
              color: isActive ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 1),
            Opacity(
              opacity: isActive ? 0.95 : 0.7,
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? activeColor : inactiveColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockDestination {
  const _DockDestination({
    required this.route,
    required this.icon,
    required this.labelKey,
  });

  final String route;
  final IconData icon;
  final String labelKey;
}
