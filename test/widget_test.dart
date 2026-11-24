import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:website_webview_app/app/app.dart';
import 'package:website_webview_app/screens/about_screen.dart';
import 'package:website_webview_app/screens/setup_screen.dart';
import 'package:website_webview_app/utils/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.example.website_webview_app/permissions'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getDefaultStoragePath') {
          return '/mock/storage';
        }
        return true;
      },
    );
  });

  group('SetupScreen UI tests', () {
    testWidgets('renders all setup screen elements', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SetupScreen()));

      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text('Welcome'), findsOneWidget);
      expect(
        find.text('Enter the website you want this app to load.'),
        findsOneWidget,
      );
      expect(find.text('Save & Open Website'), findsOneWidget);
      expect(find.text('Save as default website'), findsOneWidget);
      expect(find.text('Biometric App Lock'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows validation error on empty continue', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SetupScreen()));

      await tester.ensureVisible(find.text('Save & Open Website'));
      await tester.tap(find.text('Save & Open Website'));
      await tester.pump();

      expect(find.text(AppConstants.invalidDomainError), findsOneWidget);
    });

    testWidgets('shows validation error on invalid domain input', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SetupScreen()));

      await tester.enterText(find.byType(TextField), 'invalid domain');
      await tester.ensureVisible(find.text('Save & Open Website'));
      await tester.tap(find.text('Save & Open Website'));
      await tester.pump();

      expect(find.text(AppConstants.invalidDomainError), findsOneWidget);
    });
  });

  group('AboutScreen UI tests', () {
    testWidgets('renders about screen with app info', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: AboutScreen()));

      expect(find.text('About'), findsOneWidget);
      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text('Version ${AppConstants.appVersion}'), findsOneWidget);
    });
  });

  group('WebsiteWebViewApp test', () {
    testWidgets('renders app and navigates to setup when no saved website', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const WebsiteWebViewApp());
      await tester.pumpAndSettle(const Duration(milliseconds: 700));

      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text(AppConstants.appName), findsOneWidget);
    });
  });
}
