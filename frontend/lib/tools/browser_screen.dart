import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/video_info.dart';
import '../services/api_service.dart';
import '../services/background_download_manager.dart';
import '../services/browser_session_manager.dart';
import '../services/folder_service.dart';
import '../services/theme_controller.dart';
import '../sheets/history_sheet.dart';
import '../sheets/resolution_picker_sheet.dart';
import '../widgets/history_button.dart';
import '../widgets/neomorphic_container.dart';
import '../widgets/orbit_loader.dart';
import '../widgets/tap_scale.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  final _session = BrowserSessionManager.instance;
  final _urlBarController = TextEditingController();
  final _api = ApiService();
  final _folderService = FolderService();

  @override
  void initState() {
    super.initState();
    _session.onActiveTabChanged = () {
      if (!mounted) return;
      setState(() {});
      _urlBarController.text = _session.activeTab.currentUrl;
    };
    _urlBarController.text = _session.activeTab.currentUrl;
    // Ensure the active tab's controller exists so the WebView renders.
    _session.controllerFor(_session.activeTab);
  }

  @override
  void dispose() {
    // Only detach this screen's callback -- every tab (and its loaded page)
    // stays alive in the background unless explicitly closed.
    _session.onActiveTabChanged = null;
    _urlBarController.dispose();
    super.dispose();
  }

  void _minimize() {
    Navigator.of(context).pop();
  }

  void _closeSession() {
    _session.closeAllTabs();
    Navigator.of(context).pop();
  }

  Future<void> _goBack() async {
    final tab = _session.activeTab;
    if (!tab.canGoBack) return;
    await _session.pauseMedia(tab);
    tab.controller?.goBack();
  }

  void _goToUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return;

    var target = trimmed;
    final looksLikeUrl = target.contains('.') && !target.contains(' ');
    if (!target.startsWith('http://') && !target.startsWith('https://')) {
      target = looksLikeUrl ? 'https://$target' : '';
    }

    var uri = target.isEmpty ? null : Uri.tryParse(target);
    if (uri == null || uri.host.isEmpty) {
      uri = Uri.parse(
        'https://www.google.com/search?q=${Uri.encodeComponent(trimmed)}',
      );
    }
    _session.activeTab.controller?.loadRequest(uri);
  }

  void _newTab() {
    _session.addTab();
    _urlBarController.text = BrowserSessionManager.homeUrl;
    _session.controllerFor(_session.activeTab);
  }

  void _openTabSwitcher() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _TabSwitcherSheet(
        onSwitch: () => setState(() {
          _urlBarController.text = _session.activeTab.currentUrl;
        }),
      ),
    );
  }

  Future<void> _downloadFromCurrentPage() async {
    final url = _session.activeTab.currentUrl;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _BrowserDownloadSheet(
        url: url,
        api: _api,
        folderService: _folderService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final colors = ThemeController.instance.colors;
        final tab = _session.activeTab;
        final controller = _session.controllerFor(tab);
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _minimize();
          },
          child: Scaffold(
            backgroundColor: colors.background,
            body: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      _buildTopBar(colors, tab),
                      tab.isLoading
                          ? _buildLoadingBar(colors)
                          : const SizedBox(height: 2),
                      Expanded(child: WebViewWidget(controller: controller)),
                      _buildNavBar(colors, tab),
                    ],
                  ),
                  if (tab.videoDetected)
                    Positioned(
                      bottom: 76,
                      right: 20,
                      child: _DownloadFab(onTap: _downloadFromCurrentPage),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(colors, BrowserTab tab) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: _minimize,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: colors.textPrimary,
            ),
            tooltip: 'Minimize',
          ),
          IconButton(
            onPressed: _closeSession,
            icon: Icon(Icons.close_rounded, color: colors.textFaint, size: 20),
            tooltip: 'Close browser',
          ),
          Expanded(
            child: NeomorphicContainer(
              style: NeoStyle.pressed,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              borderRadius: BorderRadius.circular(14),
              child: TextField(
                controller: _urlBarController,
                style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
                textInputAction: TextInputAction.go,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search or enter URL',
                  hintStyle: TextStyle(color: colors.textFaint, fontSize: 13),
                ),
                onSubmitted: _goToUrl,
              ),
            ),
          ),
          IconButton(
            onPressed: () => tab.controller?.reload(),
            icon: Icon(Icons.refresh_rounded, color: colors.textFaint),
          ),
          IconButton(
            onPressed: _newTab,
            icon: Icon(Icons.add_rounded, color: colors.textFaint),
            tooltip: 'New tab',
          ),
          _TabCountButton(onTap: _openTabSwitcher),
        ],
      ),
    );
  }

  Widget _buildLoadingBar(colors) {
    return SizedBox(
      height: 2,
      child: LinearProgressIndicator(
        backgroundColor: Colors.transparent,
        valueColor: AlwaysStoppedAnimation(colors.accent),
      ),
    );
  }

  Widget _buildNavBar(colors, BrowserTab tab) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.shadowDark.withValues(alpha: 0.25)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: tab.canGoBack ? _goBack : null,
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: tab.canGoBack ? colors.textPrimary : colors.textFaint,
            ),
          ),
          IconButton(
            onPressed: tab.canGoForward
                ? () => tab.controller?.goForward()
                : null,
            icon: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: tab.canGoForward ? colors.textPrimary : colors.textFaint,
            ),
          ),
          IconButton(
            onPressed: () => _goToUrl(BrowserSessionManager.homeUrl),
            icon: Icon(Icons.home_rounded, size: 20, color: colors.textFaint),
          ),
          HistoryButton(onTap: () => showHistorySheet(context)),
        ],
      ),
    );
  }
}

class _TabCountButton extends StatelessWidget {
  final VoidCallback onTap;

  const _TabCountButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = ThemeController.instance.colors;
    final count = BrowserSessionManager.instance.tabs.length;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 30,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: colors.textFaint, width: 1.6),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            color: colors.textFaint,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TabSwitcherSheet extends StatefulWidget {
  final VoidCallback onSwitch;

  const _TabSwitcherSheet({required this.onSwitch});

  @override
  State<_TabSwitcherSheet> createState() => _TabSwitcherSheetState();
}

class _TabSwitcherSheetState extends State<_TabSwitcherSheet> {
  final _session = BrowserSessionManager.instance;

  @override
  void initState() {
    super.initState();
    _session.onTabsChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    _session.onTabsChanged = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeController.instance.colors;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 20),
        constraints: const BoxConstraints(maxHeight: 480),
        child: NeomorphicContainer(
          borderRadius: BorderRadius.circular(28),
          intensity: 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.shadowDark,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_session.tabs.length} Tabs',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TapScale(
                    onTap: () {
                      _session.addTab();
                      widget.onSwitch();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [colors.videoStart, colors.videoEnd],
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'New',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _session.tabs.length,
                  separatorBuilder: (_, __) => SizedBox(
                    height: 1,
                    child: Container(
                      color: colors.shadowDark.withValues(alpha: 0.2),
                    ),
                  ),
                  itemBuilder: (context, index) {
                    final tab = _session.tabs[index];
                    final isActive = tab.id == _session.activeTabId;
                    return InkWell(
                      onTap: () {
                        _session.switchTab(tab.id);
                        widget.onSwitch();
                        Navigator.of(context).pop();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.public_rounded,
                              size: 18,
                              color: isActive
                                  ? colors.accent
                                  : colors.textFaint,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tab.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isActive
                                          ? colors.textPrimary
                                          : colors.textSecondary,
                                      fontSize: 14,
                                      fontWeight: isActive
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    tab.currentUrl,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textFaint,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                final wasActive = isActive;
                                _session.closeTab(tab.id);
                                if (wasActive) widget.onSwitch();
                                if (_session.tabs.isEmpty) {
                                  Navigator.of(context).pop();
                                }
                              },
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: colors.textFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadFab extends StatelessWidget {
  final VoidCallback onTap;

  const _DownloadFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = ThemeController.instance.colors;
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: [colors.videoStart, colors.videoEnd],
          ),
          boxShadow: [
            BoxShadow(
              color: colors.videoStart.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Download',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Bottom sheet that fetches info for the current page URL and hands off to
// the same start-download pipeline as the home screen. Downloads started
// here now show in the normal History list like any other download.
class _BrowserDownloadSheet extends StatefulWidget {
  final String url;
  final ApiService api;
  final FolderService folderService;

  const _BrowserDownloadSheet({
    required this.url,
    required this.api,
    required this.folderService,
  });

  @override
  State<_BrowserDownloadSheet> createState() => _BrowserDownloadSheetState();
}

class _BrowserDownloadSheetState extends State<_BrowserDownloadSheet> {
  bool _loading = true;
  VideoInfo? _info;
  String? _error;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final info = await widget.api.fetchInfo(widget.url);
      if (!mounted) return;
      setState(() {
        _info = info;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _startDownload({
    String? formatId,
    bool audioOnly = false,
  }) async {
    setState(() => _starting = true);
    try {
      final folderPath = await widget.folderService.getSavedFolder();
      final jobId = await widget.api.startDownloadJob(
        url: widget.url,
        formatId: formatId,
        audioOnly: audioOnly,
        audioFormat: 'mp3',
      );
      BackgroundDownloadManager.instance.track(
        jobId: jobId,
        url: widget.url,
        folderPath: folderPath,
        audioOnly: audioOnly,
        audioFormat: 'mp3',
        fromBrowser: true,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _onDownloadVideo() async {
    final info = _info;
    if (info == null) return;
    final choices = buildResolutionLadder(info);
    if (choices.isEmpty) {
      await _startDownload();
      return;
    }
    final choice = await showResolutionPickerSheet(context, choices);
    if (choice == null || !mounted) return;
    await _startDownload(formatId: choice.formatSelector);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeController.instance.colors;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 20),
        child: NeomorphicContainer(
          borderRadius: BorderRadius.circular(28),
          intensity: 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.shadowDark,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                'Download from page',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: OrbitLoader(size: 32)),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFE85D75),
                      fontSize: 13,
                    ),
                  ),
                )
              else if (_info != null) ...[
                Text(
                  _info!.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TapScale(
                        onTap: _starting ? null : _onDownloadVideo,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [colors.videoStart, colors.videoEnd],
                            ),
                          ),
                          child: const Text(
                            'Video',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TapScale(
                        onTap: _starting
                            ? null
                            : () => _startDownload(audioOnly: true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [colors.audioStart, colors.audioEnd],
                            ),
                          ),
                          child: const Text(
                            'Audio',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
