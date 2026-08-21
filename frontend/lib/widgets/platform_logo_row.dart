import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../services/theme_controller.dart';
import 'tap_scale.dart';

class _PlatformBadge {
  final FaIconData icon;
  final Color color;

  const _PlatformBadge(this.icon, this.color);
}

const _badges = [
  _PlatformBadge(FontAwesomeIcons.facebookF, Color(0xFF1877F2)),
  _PlatformBadge(FontAwesomeIcons.instagram, Color(0xFFE1306C)),
  _PlatformBadge(FontAwesomeIcons.youtube, Color(0xFFFF0033)),
  _PlatformBadge(FontAwesomeIcons.chrome, Color(0xFF34A853)),
];

class PlatformLogoRow extends StatelessWidget {
  const PlatformLogoRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final badge in _badges) ...[
          _LogoBadge(badge: badge),
          if (badge != _badges.last) const SizedBox(width: 18),
        ],
      ],
    );
  }
}

class _LogoBadge extends StatelessWidget {
  final _PlatformBadge badge;

  const _LogoBadge({required this.badge});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final colors = ThemeController.instance.colors;
        return TapScale(
          child: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.background,
              boxShadow: [
                BoxShadow(
                  color: colors.shadowDark,
                  offset: const Offset(4, 4),
                  blurRadius: 8,
                ),
                BoxShadow(
                  color: colors.shadowLight,
                  offset: const Offset(-4, -4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: FaIcon(badge.icon, color: badge.color, size: 22),
            ),
          ),
        );
      },
    );
  }
}
