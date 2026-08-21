import 'package:flutter/material.dart';

import '../services/theme_controller.dart';
import '../tools/browser_screen.dart';
import '../tools/speed_test_screen.dart';
import '../widgets/neomorphic_container.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final colors = ThemeController.instance.colors;
        return Container(
          color: colors.background,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tools',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Extra utilities beyond downloading',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 28),
                  _ToolTile(
                    icon: Icons.speed_rounded,
                    title: 'Internet Speed Test',
                    subtitle: 'Check your current download speed',
                    colorStart: colors.videoStart,
                    colorEnd: colors.videoEnd,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SpeedTestScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _ToolTile(
                    icon: Icons.public_rounded,
                    title: 'In-app Browser',
                    subtitle: 'Browse and detect videos on any site',
                    colorStart: colors.audioStart,
                    colorEnd: colors.audioEnd,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BrowserScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color colorStart;
  final Color colorEnd;
  final VoidCallback onTap;

  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colorStart,
    required this.colorEnd,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeController.instance.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: NeomorphicContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [colorStart, colorEnd]),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(color: colors.textFaint, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textFaint),
          ],
        ),
      ),
    );
  }
}
