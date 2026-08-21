import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/tools_screen.dart';
import 'services/backend_config_service.dart';
import 'services/overlay_service.dart';
import 'services/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackendConfigService.instance.load();
  runApp(const AllIn1DownloaderApp());
}

class AllIn1DownloaderApp extends StatelessWidget {
  const AllIn1DownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final colors = ThemeController.instance.colors;
        final isLight = ThemeController.instance.isLight;
        return MaterialApp(
          title: 'All in 1 Downloader',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: isLight ? Brightness.light : Brightness.dark,
            scaffoldBackgroundColor: colors.background,
            colorScheme: ColorScheme.fromSeed(
              seedColor: colors.accent,
              brightness: isLight ? Brightness.light : Brightness.dark,
            ),
            fontFamily: 'Roboto',
          ),
          home: const AppShell(),
        );
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;
  final _homeKey = GlobalKey<HomeScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = [HomeScreen(key: _homeKey), const ToolsScreen()];
    OverlayService.setBubbleTapHandler(_onBubbleTapped);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      OverlayService.showBubble();
    } else if (state == AppLifecycleState.resumed) {
      OverlayService.hideBubble();
    }
  }

  void _onBubbleTapped() {
    setState(() => _index = 0);
    OverlayService.hideBubble();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final colors = ThemeController.instance.colors;
        return Scaffold(
          body: IndexedStack(index: _index, children: _screens),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: colors.background,
              border: Border(
                top: BorderSide(
                  color: colors.shadowDark.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: SafeArea(
              child: SizedBox(
                height: 58,
                child: Row(
                  children: [
                    Expanded(
                      child: _NavItem(
                        icon: Icons.home_rounded,
                        label: 'Home',
                        selected: _index == 0,
                        onTap: () => setState(() => _index = 0),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.build_rounded,
                        label: 'Tools',
                        selected: _index == 1,
                        onTap: () => setState(() => _index = 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeController.instance.colors;
    final color = selected ? colors.accent : colors.textFaint;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
