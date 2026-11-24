import 'package:flutter/material.dart';

import '../screens/about_screen.dart';
import '../screens/setup_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/webview_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String setup = '/setup';
  static const String webview = '/webview';
  static const String about = '/about';

  static Map<String, WidgetBuilder> get routes => {
    splash: (context) => const SplashScreen(),
    setup: (context) => const SetupScreen(),
    about: (context) => const AboutScreen(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == webview) {
      final args = settings.arguments;
      final url = args is String ? args : '';
      return MaterialPageRoute<void>(
        builder: (context) => WebViewScreen(url: url),
        settings: settings,
      );
    }
    return null;
  }
}
