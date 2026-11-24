import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app/routes.dart';
import '../services/storage_service.dart';
import '../services/webview_service.dart';
import '../utils/constants.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/sync_storage_dialog.dart';

enum _WebViewMenuAction {
  savedWebsites,
  saveAsDefault,
  storageSync,
  copyLink,
  toggleDesktopMode,
  toggleDarkMode,
  refresh,
  clearBrowsingData,
  changeWebsite,
  about,
}

class WebViewScreen extends StatefulWidget {
  final String url;
  final StorageService? storageService;
  final WebViewService? webViewService;

  const WebViewScreen({
    super.key,
    required this.url,
    this.storageService,
    this.webViewService,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  late final StorageService _storageService;
  late final WebViewService _webViewService;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  int _progress = 0;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isOffline = false;
  bool _isDesktopMode = false;
  bool _isDarkMode = false;
  String _pageTitle = AppConstants.appName;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _storageService = widget.storageService ?? StorageService();
    _webViewService = widget.webViewService ?? const WebViewService();

    // Auto-save & real-time sync the initial URL
    _storageService.addSavedWebsite(widget.url);
    _storageService.syncWebsiteToStorage(
      url: widget.url,
      title: 'Initial Website',
      type: 'Startup Launch',
    );

    _initConnectivityListener();
    _initWebViewController();
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final isOffline = results.every((r) => r == ConnectivityResult.none);
      if (mounted) {
        if (_isOffline && !isOffline) {
          // Reconnected to internet
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.wifi_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Connection restored. Reloading...'),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          _handleRefresh();
        }
        setState(() {
          _isOffline = isOffline;
        });
      }
    });
  }

  void _initWebViewController() {
    _controller = _webViewService.createController(
      initialUrl: widget.url,
      isDesktopMode: _isDesktopMode,
      onProgress: (progress) {
        if (!mounted) return;
        setState(() {
          _progress = progress;
          _isLoading = progress < 100;
        });
      },
      onPageStarted: (url) {
        if (!mounted) return;
        setState(() {
          _currentUrl = url;
          _isLoading = true;
          _hasError = false;
        });
      },
      onPageFinished: (url) async {
        if (!mounted) return;
        final title = await _controller.getTitle();
        final actualUrl = await _controller.currentUrl();
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          if (actualUrl != null && actualUrl.isNotEmpty) {
            _currentUrl = actualUrl;
          }
          if (title != null && title.isNotEmpty) {
            _pageTitle = title;
          }
        });

        // Apply dark mode CSS if enabled
        if (_isDarkMode) {
          _applyDarkModeCss(true);
        }

        // Auto-save & real-time sync visited URLs to mobile storage file
        if (actualUrl != null && actualUrl.isNotEmpty) {
          _storageService.addSavedWebsite(actualUrl);
          _storageService.syncWebsiteToStorage(
            url: actualUrl,
            title: title ?? _pageTitle,
            type: 'Visited Link',
          );
        }
      },
      onWebResourceError: (error) {
        if (!mounted) return;
        if (error.isForMainFrame ?? true) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    await _controller.reload();
  }

  Future<void> _handleCopyLink() async {
    final targetUrl = _currentUrl.isNotEmpty ? _currentUrl : widget.url;
    await Clipboard.setData(ClipboardData(text: targetUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.copy_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Link copied to clipboard'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleClearBrowsingData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear Browsing Data?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This will clear the web cache, stored cookies, and local session storage.',
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _controller.clearCache();
        await _controller.clearLocalStorage();
        final cookieManager = WebViewCookieManager();
        await cookieManager.clearCookies();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(
                  Icons.cleaning_services_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text('Cache, cookies, and local storage cleared.'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        await _handleRefresh();
      } catch (e) {
        debugPrint('Error clearing browsing data: $e');
      }
    }
  }

  Future<void> _toggleDesktopMode() async {
    setState(() {
      _isDesktopMode = !_isDesktopMode;
      _isLoading = true;
    });

    if (_isDesktopMode) {
      await _controller.setUserAgent(WebViewService.desktopUserAgent);
    } else {
      await _controller.setUserAgent(null);
    }

    await _controller.reload();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isDesktopMode ? 'Desktop view enabled' : 'Mobile view enabled',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleDarkMode() async {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    await _applyDarkModeCss(_isDarkMode);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isDarkMode ? 'Dark web theme active' : 'Light web theme active',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _applyDarkModeCss(bool enable) async {
    try {
      if (enable) {
        await _controller.runJavaScript('''
          (function() {
            var css = 'html { filter: invert(0.9) hue-rotate(180deg) !important; background: #121212 !important; } img, video, iframe, canvas { filter: invert(1.1) hue-rotate(180deg) !important; }';
            var head = document.head || document.getElementsByTagName('head')[0];
            var style = document.getElementById('dark-mode-style');
            if (!style) {
              style = document.createElement('style');
              style.id = 'dark-mode-style';
              style.type = 'text/css';
              style.appendChild(document.createTextNode(css));
              head.appendChild(style);
            }
          })();
        ''');
      } else {
        await _controller.runJavaScript('''
          (function() {
            var style = document.getElementById('dark-mode-style');
            if (style) {
              style.remove();
            }
          })();
        ''');
      }
    } catch (_) {}
  }

  Future<void> _handleSaveCurrentWebsite() async {
    final targetUrl = _currentUrl.isNotEmpty ? _currentUrl : widget.url;
    try {
      await _storageService.saveWebsiteUrl(targetUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Saved as default startup: $targetUrl')),
            ],
          ),
          backgroundColor: const Color(0xFF1F2937),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Error saving website URL: $e\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save website configuration.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _handleChangeWebsite() async {
    try {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.setup);
    } catch (e, stackTrace) {
      debugPrint('Error navigating to setup: $e\n$stackTrace');
    }
  }

  void _handleAbout() {
    Navigator.pushNamed(context, AppRoutes.about);
  }

  Future<void> _showSavedWebsitesSheet() async {
    final list = await _storageService.getSavedWebsites();
    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          expand: false,
          builder: (ctx, scrollController) {
            return Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  height: 5,
                  width: 38,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF38383A)
                        : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bookmarks_rounded,
                            size: 20,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Saved Websites (${list.length})',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2C2C2E)
                                : const Color(0xFFF3F4F6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_rounded, size: 18),
                        ),
                        tooltip: 'Search / Enter New',
                        onPressed: () {
                          Navigator.pop(ctx);
                          _handleChangeWebsite();
                        },
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFE5E7EB),
                ),
                if (list.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        'No saved websites yet.',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFF8E8E93)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      itemCount: list.length,
                      itemBuilder: (ctx, index) {
                        final savedUrl = list[index];
                        final isCurrent =
                            savedUrl == _currentUrl || savedUrl == widget.url;
                        final uri = Uri.tryParse(savedUrl);
                        final host = uri?.host.isNotEmpty == true
                            ? uri!.host
                            : savedUrl;
                        final firstLetter = host.isNotEmpty
                            ? host.replaceFirst('www.', '')[0].toUpperCase()
                            : 'W';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Material(
                            color: isDark
                                ? const Color(0xFF2C2C2E)
                                : const Color(0xFFF9FAFB),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: isCurrent
                                    ? primaryColor
                                    : isDark
                                    ? const Color(0xFF38383A)
                                    : const Color(0xFFE5E7EB),
                                width: isCurrent ? 1.5 : 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 2,
                              ),
                              leading: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? primaryColor
                                      : isDark
                                      ? const Color(0xFF3A3A3C)
                                      : const Color(0xFFE5E7EB),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    firstLetter,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: isCurrent
                                          ? Colors.white
                                          : isDark
                                          ? Colors.white70
                                          : const Color(0xFF374151),
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                host,
                                style: TextStyle(
                                  fontWeight: isCurrent
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF111827),
                                ),
                              ),
                              subtitle: Text(
                                savedUrl,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFF8E8E93)
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                              trailing: isCurrent
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981)
                                            .withAlpha(30),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Active',
                                        style: TextStyle(
                                          color: Color(0xFF10B981),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 14,
                                    ),
                              onTap: () {
                                Navigator.pop(ctx);
                                if (!isCurrent) {
                                  setState(() {
                                    _currentUrl = savedUrl;
                                    _isLoading = true;
                                    _hasError = false;
                                  });
                                  _controller.loadRequest(Uri.parse(savedUrl));
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _retryLoading() {
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    _controller.loadRequest(
      Uri.parse(_currentUrl.isNotEmpty ? _currentUrl : widget.url),
    );
  }

  String _getDomainTitle() {
    final uri = Uri.tryParse(_currentUrl);
    if (uri != null && uri.host.isNotEmpty) {
      return uri.host;
    }
    return _pageTitle.isNotEmpty ? _pageTitle : AppConstants.appName;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final displayDomain = _getDomainTitle();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else {
          if (context.mounted) {
            await _handleChangeWebsite();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Search / Change Website',
            onPressed: _handleChangeWebsite,
          ),
          title: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _showSavedWebsitesSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF38383A)
                      : const Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _currentUrl.startsWith('https')
                        ? Icons.lock_rounded
                        : Icons.lock_open_rounded,
                    size: 13,
                    color: _currentUrl.startsWith('https')
                        ? const Color(0xFF10B981)
                        : (isDark
                              ? const Color(0xFF8E8E93)
                              : const Color(0xFF6B7280)),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      displayDomain,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: isDark
                        ? const Color(0xFF8E8E93)
                        : const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.bookmarks_rounded, size: 20),
              tooltip: 'Saved Websites',
              onPressed: _showSavedWebsitesSheet,
            ),
            PopupMenuButton<_WebViewMenuAction>(
              icon: const Icon(Icons.more_vert_rounded),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              onSelected: (action) {
                switch (action) {
                  case _WebViewMenuAction.savedWebsites:
                    _showSavedWebsitesSheet();
                    break;
                  case _WebViewMenuAction.saveAsDefault:
                    _handleSaveCurrentWebsite();
                    break;
                  case _WebViewMenuAction.storageSync:
                    SyncStorageDialog.show(
                      context,
                      storageService: _storageService,
                    );
                    break;
                  case _WebViewMenuAction.copyLink:
                    _handleCopyLink();
                    break;
                  case _WebViewMenuAction.toggleDesktopMode:
                    _toggleDesktopMode();
                    break;
                  case _WebViewMenuAction.toggleDarkMode:
                    _toggleDarkMode();
                    break;
                  case _WebViewMenuAction.refresh:
                    _handleRefresh();
                    break;
                  case _WebViewMenuAction.clearBrowsingData:
                    _handleClearBrowsingData();
                    break;
                  case _WebViewMenuAction.changeWebsite:
                    _handleChangeWebsite();
                    break;
                  case _WebViewMenuAction.about:
                    _handleAbout();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: _WebViewMenuAction.savedWebsites,
                  child: Row(
                    children: [
                      Icon(Icons.bookmarks_outlined, size: 18),
                      SizedBox(width: 12),
                      Text(
                        'All Saved Websites',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: _WebViewMenuAction.saveAsDefault,
                  child: Row(
                    children: [
                      Icon(Icons.star_outline_rounded, size: 18),
                      SizedBox(width: 12),
                      Text(
                        'Set as Default Startup',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: _WebViewMenuAction.storageSync,
                  child: Row(
                    children: [
                      Icon(Icons.sync_rounded, size: 18),
                      SizedBox(width: 12),
                      Text(
                        'Auto Storage Sync File',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: _WebViewMenuAction.copyLink,
                  child: Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 18),
                      SizedBox(width: 12),
                      Text('Copy Page Link', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _WebViewMenuAction.toggleDesktopMode,
                  child: Row(
                    children: [
                      Icon(
                        _isDesktopMode
                            ? Icons.desktop_windows_rounded
                            : Icons.smartphone_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isDesktopMode
                            ? 'Switch to Mobile View'
                            : 'Request Desktop Site',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _WebViewMenuAction.toggleDarkMode,
                  child: Row(
                    children: [
                      Icon(
                        _isDarkMode
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isDarkMode
                            ? 'Light Web Theme'
                            : 'Force Dark Web Theme',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: _WebViewMenuAction.refresh,
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, size: 18),
                      SizedBox(width: 12),
                      Text('Refresh', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: _WebViewMenuAction.clearBrowsingData,
                  child: Row(
                    children: [
                      Icon(Icons.cleaning_services_outlined, size: 18),
                      SizedBox(width: 12),
                      Text(
                        'Clear Cache & Cookies',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: _WebViewMenuAction.changeWebsite,
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 18),
                      SizedBox(width: 12),
                      Text(
                        'Search / New Website',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: _WebViewMenuAction.about,
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18),
                      SizedBox(width: 12),
                      Text('About', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ],
          bottom: _isLoading && !_hasError
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2.5),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress / 100.0 : null,
                    minHeight: 2.5,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                )
              : null,
        ),
        body: Column(
          children: [
            if (_isOffline) _buildOfflineBanner(),
            Expanded(child: _hasError ? _buildErrorView() : _buildWebView()),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withAlpha(60),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'No internet connection. Waiting for network...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          InkWell(
            onTap: _handleRefresh,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: Theme.of(context).colorScheme.primary,
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading && _progress < 75)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _isLoading ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  color: (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC))
                      .withAlpha(235),
                  child: const Center(
                    child: LoadingIndicator(
                      size: 72,
                      message: 'Loading website...',
                      use3D: true,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1C1C1E)
                    : const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFFEE2E2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppConstants.webViewLoadError,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                AppConstants.webViewLoadErrorSubtitle,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isDark
                      ? const Color(0xFF8E8E93)
                      : const Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _handleChangeWebsite,
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text('Change URL'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _retryLoading,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
