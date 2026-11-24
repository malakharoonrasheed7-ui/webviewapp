class UrlValidator {
  UrlValidator._();

  static String? normalize(String input) {
    String value = input.trim();

    if (value.isEmpty) {
      return null;
    }

    // Add https:// if the user did not provide a protocol
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }

    final uri = Uri.tryParse(value);

    if (uri == null ||
        uri.host.isEmpty ||
        !uri.host.contains('.') ||
        uri.host.contains(' ') ||
        uri.host.startsWith('.') ||
        uri.host.endsWith('.')) {
      return null;
    }

    return uri.toString();
  }
}
