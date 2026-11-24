import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class WebViewService {
  const WebViewService();

  static const String desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';

  static final List<String> _downloadExtensions = [
    '.pdf',
    '.apk',
    '.zip',
    '.rar',
    '.7z',
    '.tar',
    '.gz',
    '.docx',
    '.xlsx',
    '.pptx',
    '.csv',
    '.mp3',
    '.mp4',
    '.wav',
    '.epub',
    '.dmg',
    '.exe',
    '.iso',
    '.msi',
  ];

  static bool isDownloadableUrl(String url) {
    final lower = url.toLowerCase();
    return _downloadExtensions.any((ext) => lower.contains(ext));
  }

  /// Creates and configures a [WebViewController] with full permission and scheme support.
  WebViewController createController({
    required String initialUrl,
    required ValueChanged<int> onProgress,
    required ValueChanged<String> onPageStarted,
    required ValueChanged<String> onPageFinished,
    required ValueChanged<WebResourceError> onWebResourceError,
    bool isDesktopMode = false,
  }) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: onProgress,
          onPageStarted: (url) {
            debugPrint('Page started loading: $url');
            onPageStarted(url);
          },
          onPageFinished: (url) {
            debugPrint('Page finished loading: $url');
            onPageFinished(url);
          },
          onWebResourceError: (error) {
            debugPrint(
              'Web resource error [${error.errorCode}]: ${error.description}',
            );
            onWebResourceError(error);
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();

            // Handle external schemes and downloads
            if (url.startsWith('mailto:') ||
                url.startsWith('tel:') ||
                url.startsWith('sms:') ||
                url.startsWith('whatsapp:') ||
                url.startsWith('intent:') ||
                url.startsWith('tg:') ||
                isDownloadableUrl(url)) {
              try {
                launchUrl(
                  Uri.parse(request.url),
                  mode: LaunchMode.externalApplication,
                );
                return NavigationDecision.prevent;
              } catch (e) {
                debugPrint('Error launching external URL: $e');
              }
            }

            return NavigationDecision.navigate;
          },
        ),
      );

    if (isDesktopMode) {
      controller.setUserAgent(desktopUserAgent);
    }

    // Configure Android specific features (Camera, Mic, Geolocation permissions)
    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      androidController.setOnPlatformPermissionRequest((request) {
        debugPrint('WebView permission requested for: ${request.types}');
        request.grant();
      });
      androidController.setGeolocationPermissionsPromptCallbacks(
        onShowPrompt: (request) async =>
            const GeolocationPermissionsResponse(allow: true, retain: true),
      );
    }

    controller.loadRequest(Uri.parse(initialUrl));
    return controller;
  }
}
