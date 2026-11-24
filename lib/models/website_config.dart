class WebsiteConfig {
  final String url;

  const WebsiteConfig({required this.url});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebsiteConfig &&
          runtimeType == other.runtimeType &&
          url == other.url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'WebsiteConfig(url: $url)';
}
