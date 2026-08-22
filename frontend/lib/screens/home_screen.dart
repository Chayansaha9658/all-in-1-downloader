import 'package:flutter/material.dart';

import '../models/video_info.dart';
import '../services/api_service.dart';
import '../services/theme_controller.dart';
import '../sheets/backend_settings_sheet.dart';
import '../sheets/history_sheet.dart';
import '../sheets/resolution_picker_sheet.dart';
import '../widgets/backend_setup_banner.dart';
import '../widgets/download_flow_overlay.dart';
import '../widgets/gradient_action_button.dart';
import '../widgets/history_button.dart';
import '../widgets/link_input_field.dart';
import '../widgets/neomorphic_container.dart';
import '../widgets/platform_logo_row.dart';
import '../widgets/theme_toggle_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  final _api = ApiService();

  bool _isFetching = false;
  VideoInfo? _info;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void setLinkFromExternal(String link) {
    _controller.text = link;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    setState(() {
      _info = null;
      _error = null;
    });
    _fetchInfo();
  }

  Future<void> _fetchInfo() async {
    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Paste a link first');
      return;
    }
    setState(() {
      _isFetching = true;
      _error = null;
      _info = null;
    });
    try {
      final info = await _api.fetchInfo(url);
      if (!mounted) return;
      setState(() => _info = info);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  Future<void> _onDownloadVideo() async {
    final info = _info;
    if (info == null) return;
    final choices = buildResolutionLadder(info);
    if (choices.isEmpty) {
      await _runDownloadFlow();
      return;
    }
    final choice = await showResolutionPickerSheet(context, choices);
    if (choice == null || !mounted) return;
    await _runDownloadFlow(formatId: choice.formatSelector);
  }

  Future<void> _onDownloadAudio() async {
    if (_info == null) return;
    await _runDownloadFlow(audioOnly: true, audioFormat: 'mp3');
  }

  Future<void> _runDownloadFlow({
    String? formatId,
    bool audioOnly = false,
    String audioFormat = 'mp3',
  }) async {
    await showDownloadFlowOverlay(
      context,
      url: _controller.text.trim(),
      formatId: formatId,
      audioOnly: audioOnly,
      audioFormat: audioFormat,
      title: _info?.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canDownload = _info != null;
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final colors = ThemeController.instance.colors;
        return Scaffold(
          backgroundColor: colors.background,
          body: Stack(
            children: [
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'All in 1 Downloader',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Download from YouTube, Facebook, Instagram, and any link',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const BackendSetupBanner(),
                      const PlatformLogoRow(),
                      const SizedBox(height: 30),
                      LinkInputField(
                        controller: _controller,
                        isLoading: _isFetching,
                        onSearch: _fetchInfo,
                        onClear: () {
                          setState(() {
                            _info = null;
                            _error = null;
                          });
                        },
                      ),
                      const SizedBox(height: 6),
                      _TopLoadingBar(active: _isFetching),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFE85D75),
                            fontSize: 13,
                          ),
                        ),
                      ],
                      if (_info != null) ...[
                        const SizedBox(height: 18),
                        _VideoPreviewCard(info: _info!),
                      ],
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          Expanded(
                            child: GradientActionButton(
                              label: 'Download Video',
                              icon: Icons.movie_creation_rounded,
                              colorStart: colors.videoStart,
                              colorEnd: colors.videoEnd,
                              onTap: canDownload ? _onDownloadVideo : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: GradientActionButton(
                              label: 'Download Audio',
                              icon: Icons.headphones_rounded,
                              colorStart: colors.audioStart,
                              colorEnd: colors.audioEnd,
                              onTap: canDownload ? _onDownloadAudio : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 16,
                child: SafeArea(
                  bottom: false,
                  child: Text(
                    'Dev-Chayan',
                    style: TextStyle(
                      color: colors.textFaint.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 12,
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      _SettingsButton(
                        onTap: () => showBackendSettingsSheet(context),
                      ),
                      const SizedBox(width: 8),
                      const ThemeToggleButton(),
                      const SizedBox(width: 8),
                      HistoryButton(onTap: () => showHistorySheet(context)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopLoadingBar extends StatefulWidget {
  final bool active;

  const _TopLoadingBar({required this.active});

  @override
  State<_TopLoadingBar> createState() => _TopLoadingBarState();
}

class _TopLoadingBarState extends State<_TopLoadingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _TopLoadingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox(height: 3);
    final colors = ThemeController.instance.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 3,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _LoadingBarPainter(_controller.value, colors.accent),
              size: const Size(double.infinity, 3),
            );
          },
        ),
      ),
    );
  }
}

class _LoadingBarPainter extends CustomPainter {
  final double t;
  final Color color;

  _LoadingBarPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = color.withValues(alpha: 0.08);
    canvas.drawRect(Offset.zero & size, bg);

    final barWidth = size.width * 0.32;
    final travel = size.width + barWidth;
    final x = -barWidth + travel * t;

    final barPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.9),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(x, 0, barWidth, size.height));
    canvas.drawRect(Rect.fromLTWH(x, 0, barWidth, size.height), barPaint);
  }

  @override
  bool shouldRepaint(covariant _LoadingBarPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.color != color;
}

class _SettingsButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SettingsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = ThemeController.instance.colors;
    return GestureDetector(
      onTap: onTap,
      child: NeomorphicContainer(
        padding: const EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(999),
        intensity: 4,
        child: Icon(
          Icons.settings_rounded,
          color: colors.textPrimary,
          size: 18,
        ),
      ),
    );
  }
}

class _VideoPreviewCard extends StatelessWidget {
  final VideoInfo info;

  const _VideoPreviewCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final colors = ThemeController.instance.colors;
    return NeomorphicContainer(
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(20),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: info.thumbnail != null
                ? Image.network(
                    info.thumbnail!,
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _thumbFallback(colors),
                  )
                : _thumbFallback(colors),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  info.uploader ?? info.extractor,
                  style: TextStyle(color: colors.textFaint, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbFallback(colors) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colors.videoStart, colors.videoEnd]),
      ),
      child: const Icon(Icons.movie_rounded, color: Colors.white, size: 28),
    );
  }
}
