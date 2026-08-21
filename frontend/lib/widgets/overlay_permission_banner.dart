import 'dart:io';

import 'package:flutter/material.dart';

import '../services/overlay_service.dart';
import '../services/theme_controller.dart';
import 'neomorphic_container.dart';
import 'tap_scale.dart';

class OverlayPermissionBanner extends StatefulWidget {
  const OverlayPermissionBanner({super.key});

  @override
  State<OverlayPermissionBanner> createState() =>
      _OverlayPermissionBannerState();
}

class _OverlayPermissionBannerState extends State<OverlayPermissionBanner>
    with WidgetsBindingObserver {
  bool _checked = false;
  bool _hasPermission = true;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addObserver(this);
      _check();
    } else {
      _checked = true;
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check when returning from the system permission screen.
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final granted = await OverlayService.hasPermission();
    if (!mounted) return;
    setState(() {
      _hasPermission = granted;
      _checked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid || !_checked || _hasPermission || _dismissed) {
      return const SizedBox.shrink();
    }
    final colors = ThemeController.instance.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: NeomorphicContainer(
        padding: const EdgeInsets.all(14),
        borderRadius: BorderRadius.circular(18),
        child: Row(
          children: [
            Icon(
              Icons.notifications_active_rounded,
              color: colors.accent,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enable floating bubble',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Get notified of video links even when the app is minimized',
                    style: TextStyle(color: colors.textFaint, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TapScale(
              onTap: () => OverlayService.requestPermission(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Allow',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            TapScale(
              onTap: () => setState(() => _dismissed = true),
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.close_rounded,
                  color: colors.textFaint,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
