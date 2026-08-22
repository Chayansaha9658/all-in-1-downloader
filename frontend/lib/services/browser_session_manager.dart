import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _desktopUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

const _mobileUserAgent =
    'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

const _videoWatcherScript = '''
(function () {
  if (window.__aid1Installed) return;
  window.__aid1Installed = true;

  function reportVideos() {
    var videos = document.querySelectorAll('video');
    window.VideoDetector.postMessage(videos.length > 0 ? 'found' : 'none');
  }

  function reportMediaUrl(url) {
    if (!url || typeof url !== 'string') return;
    if (/\\.(mp4|m3u8|webm|mov)(\\?|\$)/i.test(url)) {
      window.MediaUrlDetector.postMessage(url);
    }
  }

  function scanMediaTags() {
    document.querySelectorAll('video, source').forEach(function (el) {
      reportMediaUrl(el.currentSrc || el.src);
    });
  }

  // Covers players that set the source via JS (fetch/XHR) instead of a
  // plain HTML src attribute -- catches the request on the way out.
  var origFetch = window.fetch;
  if (origFetch) {
    window.fetch = function (input) {
      try {
        reportMediaUrl(typeof input === 'string' ? input : (input && input.url));
      } catch (e) {}
      return origFetch.apply(this, arguments);
    };
  }

  var origOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function (method, url) {
    try { reportMediaUrl(url); } catch (e) {}
    return origOpen.apply(this, arguments);
  };

  reportVideos();
  scanMediaTags();
  var observer = new MutationObserver(function () {
    reportVideos();
    scanMediaTags();
  });
  observer.observe(document.body, { childList: true, subtree: true });
  setInterval(function () {
    reportVideos();
    scanMediaTags();
  }, 2000);
})();
''';

const _pauseMediaScript =
    "document.querySelectorAll('video,audio').forEach(function(m){m.pause();});";

/// One browser tab's state. Each tab owns its own WebViewController so
/// switching tabs never reloads or loses the others' pages.
class BrowserTab {
  BrowserTab(this.id, {this.currentUrl = BrowserSessionManager.homeUrl});

  final String id;
  WebViewController? controller;
  String currentUrl;
  String title = 'New tab';
  bool canGoBack = false;
  bool canGoForward = false;
  bool videoDetected = false;
  // The direct .mp4/.m3u8 link sniffed off the page, if any -- preferred
  // over currentUrl when starting a download since it's a raw media file
  // link, which yt-dlp's generic extractor handles far more reliably than
  // an arbitrary page URL.
  String? detectedMediaUrl;
  bool isLoading = false;
}

/// Owns every open browser tab plus which one is active. Survives the
/// BrowserScreen widget's lifecycle so minimizing (popping the route)
/// never loses any tab's page. [onActiveTabChanged] fires only for updates
/// to the currently-shown tab (drives the open BrowserScreen's rebuild);
/// [onTabsChanged] fires whenever the tab list itself changes (drives the
/// tab-switcher sheet).
class BrowserSessionManager {
  BrowserSessionManager._();
  static final BrowserSessionManager instance = BrowserSessionManager._();

  static const String homeUrl = 'https://www.google.com';

  final List<BrowserTab> tabs = [];
  String? activeTabId;
  int _nextId = 1;

  VoidCallback? onActiveTabChanged;
  VoidCallback? onTabsChanged;

  BrowserTab get activeTab {
    if (tabs.isEmpty) {
      final tab = BrowserTab('${_nextId++}');
      tabs.add(tab);
      activeTabId = tab.id;
    }
    return tabs.firstWhere((t) => t.id == activeTabId, orElse: () => tabs.last);
  }

  BrowserTab addTab({String url = homeUrl}) {
    final tab = BrowserTab('${_nextId++}', currentUrl: url);
    tabs.add(tab);
    activeTabId = tab.id;
    onTabsChanged?.call();
    onActiveTabChanged?.call();
    return tab;
  }

  void switchTab(String id) {
    if (activeTabId == id) return;
    activeTabId = id;
    onActiveTabChanged?.call();
  }

  void closeTab(String id) {
    final index = tabs.indexWhere((t) => t.id == id);
    if (index == -1) return;
    tabs.removeAt(index);
    if (activeTabId == id) {
      if (tabs.isEmpty) {
        activeTabId = null;
      } else {
        activeTabId = tabs[index.clamp(0, tabs.length - 1)].id;
      }
      onActiveTabChanged?.call();
    }
    onTabsChanged?.call();
  }

  void closeAllTabs() {
    tabs.clear();
    activeTabId = null;
  }

  WebViewController controllerFor(BrowserTab tab) {
    final existing = tab.controller;
    if (existing != null) return existing;

    late final WebViewController created;
    created = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        (Platform.isMacOS || Platform.isWindows || Platform.isLinux)
            ? _desktopUserAgent
            : _mobileUserAgent,
      )
      ..addJavaScriptChannel(
        'VideoDetector',
        onMessageReceived: (message) {
          tab.videoDetected = message.message == 'found';
          if (tab.id == activeTabId) onActiveTabChanged?.call();
        },
      )
      ..addJavaScriptChannel(
        'MediaUrlDetector',
        onMessageReceived: (message) {
          tab.detectedMediaUrl = message.message;
          if (tab.id == activeTabId) onActiveTabChanged?.call();
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            tab.currentUrl = url;
            tab.isLoading = true;
            tab.videoDetected = false;
            tab.detectedMediaUrl = null;
            if (tab.id == activeTabId) onActiveTabChanged?.call();
          },
          onPageFinished: (url) async {
            await created.runJavaScript(_videoWatcherScript);
            tab.canGoBack = await created.canGoBack();
            tab.canGoForward = await created.canGoForward();
            tab.currentUrl = url;
            tab.isLoading = false;
            try {
              final pageTitle = await created.getTitle();
              if (pageTitle != null && pageTitle.isNotEmpty) {
                tab.title = pageTitle;
              }
            } catch (_) {}
            if (tab.id == activeTabId) onActiveTabChanged?.call();
            onTabsChanged?.call();
          },
          onWebResourceError: (error) {
            tab.isLoading = false;
            if (tab.id == activeTabId) onActiveTabChanged?.call();
          },
        ),
      )
      ..loadRequest(Uri.parse(tab.currentUrl));

    tab.controller = created;
    return created;
  }

  /// Pauses any playing video/audio on [tab] -- used right before navigating
  /// back so playback doesn't keep running once the page is left behind.
  Future<void> pauseMedia(BrowserTab tab) async {
    final controller = tab.controller;
    if (controller == null) return;
    try {
      await controller.runJavaScript(_pauseMediaScript);
    } catch (_) {}
  }
}
