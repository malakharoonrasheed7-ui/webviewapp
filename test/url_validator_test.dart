import 'package:flutter_test/flutter_test.dart';
import 'package:website_webview_app/utils/url_validator.dart';

void main() {
  group('UrlValidator.normalize', () {
    test('prepends https:// when protocol is missing', () {
      expect(
        UrlValidator.normalize('example.com'),
        equals('https://example.com'),
      );
      expect(
        UrlValidator.normalize('www.example.com'),
        equals('https://www.example.com'),
      );
      expect(
        UrlValidator.normalize('sub.domain.org'),
        equals('https://sub.domain.org'),
      );
    });

    test('preserves https:// protocol', () {
      expect(
        UrlValidator.normalize('https://example.com'),
        equals('https://example.com'),
      );
      expect(
        UrlValidator.normalize('https://www.example.com'),
        equals('https://www.example.com'),
      );
    });

    test('preserves http:// protocol', () {
      expect(
        UrlValidator.normalize('http://example.com'),
        equals('http://example.com'),
      );
      expect(
        UrlValidator.normalize('http://test.org'),
        equals('http://test.org'),
      );
    });

    test('handles leading and trailing whitespace', () {
      expect(
        UrlValidator.normalize('   example.com   '),
        equals('https://example.com'),
      );
      expect(
        UrlValidator.normalize('  https://example.com  '),
        equals('https://example.com'),
      );
      expect(
        UrlValidator.normalize('\thttp://example.com\n'),
        equals('http://example.com'),
      );
    });

    test('returns null for empty or whitespace-only inputs', () {
      expect(UrlValidator.normalize(''), isNull);
      expect(UrlValidator.normalize('   '), isNull);
      expect(UrlValidator.normalize('\t\n'), isNull);
    });

    test('returns null for obviously invalid domain inputs', () {
      expect(UrlValidator.normalize('hello'), isNull);
      expect(UrlValidator.normalize('not a domain'), isNull);
      expect(UrlValidator.normalize('.example.com'), isNull);
      expect(UrlValidator.normalize('example.com.'), isNull);
    });
  });
}
