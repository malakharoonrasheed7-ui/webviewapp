import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/routes.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/url_validator.dart';
import '../widgets/domain_input.dart';
import '../widgets/sync_storage_dialog.dart';
import '../widgets/three_d_tilt_card.dart';

class SetupScreen extends StatefulWidget {
  final StorageService? storageService;
  final AuthService? authService;

  const SetupScreen({super.key, this.storageService, this.authService});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final TextEditingController _domainController = TextEditingController();
  late final StorageService _storageService;
  late final AuthService _authService;
  bool _isLoading = false;
  bool _saveAsDefault = true;
  bool _isBiometricLockEnabled = false;
  String? _defaultUrl;
  List<String> _savedWebsites = [];

  final List<String> _quickSuggestions = const [
    'flutter.dev',
    'google.com',
    'github.com',
    'wikipedia.org',
    'news.ycombinator.com',
  ];

  @override
  void initState() {
    super.initState();
    _storageService = widget.storageService ?? StorageService();
    _authService = widget.authService ?? AuthService();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    try {
      final defaultUrl = await _storageService.getWebsiteUrl();
      final list = await _storageService.getSavedWebsites();
      final biometricEnabled = await _authService.isBiometricLockEnabled();
      if (mounted) {
        setState(() {
          _defaultUrl = defaultUrl;
          _savedWebsites = list;
          _isBiometricLockEnabled = biometricEnabled;
          if (defaultUrl != null &&
              defaultUrl.isNotEmpty &&
              _domainController.text.isEmpty) {
            _domainController.text = defaultUrl;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _domainController.dispose();
    super.dispose();
  }

  Future<void> _toggleBiometricLock(bool value) async {
    if (value) {
      // Authenticate before enabling
      final success = await _authService.authenticate(
        reason: 'Authenticate to enable Biometric App Lock',
      );
      if (!success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Authentication failed. Biometric Lock not enabled.',
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }
    }

    await _authService.setBiometricLockEnabled(value);
    if (!mounted) return;
    setState(() {
      _isBiometricLockEnabled = value;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              value ? Icons.fingerprint_rounded : Icons.lock_open_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              value
                  ? 'Biometric App Lock enabled'
                  : 'Biometric App Lock disabled',
            ),
          ],
        ),
        backgroundColor: value
            ? const Color(0xFF10B981)
            : const Color(0xFF374151),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openWebsite(String rawUrl, {bool setAsDefault = true}) async {
    if (_isLoading) return;

    final normalizedUrl = UrlValidator.normalize(rawUrl);
    if (normalizedUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(AppConstants.invalidDomainError)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade600,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Always store locally so closing & reopening the app goes straight to the WebView
      await _storageService.saveWebsiteUrl(normalizedUrl);
      await _storageService.addSavedWebsite(normalizedUrl);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('Saved locally & opening: $normalizedUrl')),
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

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.webview,
        arguments: normalizedUrl,
      );
    } catch (e, stackTrace) {
      debugPrint('Error saving and launching website: $e\n$stackTrace');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save website. Please try again.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _handleDeleteWebsite(String url) async {
    await _storageService.removeSavedWebsite(url);
    await _loadSavedData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed $url'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleSetAsDefault(String url) async {
    await _storageService.saveWebsiteUrl(url);
    await _loadSavedData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Saved as auto-launch domain: $url')),
          ],
        ),
        backgroundColor: const Color(0xFF1F2937),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleClearAllSaved() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear All Saved Websites?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This will remove all saved websites and reset the default configuration.',
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
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _storageService.clearAllSavedWebsites();
      await _loadSavedData();
    }
  }

  Future<void> _handleExportExcelCsv() async {
    final csvContent = await _storageService.exportToCsv();
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.table_chart_rounded,
                        color: Color(0xFF10B981),
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Excel / CSV Export',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Your saved websites list formatted for Microsoft Excel, Google Sheets, or local storage backup:',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? const Color(0xFF8E8E93)
                      : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    csvContent,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: csvContent));
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text('Excel / CSV data copied to clipboard!'),
                        ],
                      ),
                      backgroundColor: const Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy CSV Data to Clipboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            AppConstants.appName,
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sync_rounded, size: 18),
              ),
              tooltip: 'Storage File Sync & Custom Folder',
              onPressed: () => SyncStorageDialog.show(
                context,
                storageService: _storageService,
              ),
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
                child: const Icon(Icons.info_outline_rounded, size: 18),
              ),
              tooltip: 'About',
              onPressed: () => Navigator.pushNamed(context, AppRoutes.about),
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1C1C1E)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 50 : 15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: primaryColor,
                unselectedLabelColor: isDark
                    ? const Color(0xFF8E8E93)
                    : const Color(0xFF6B7280),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: [
                  const Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Search & Enter'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bookmarks_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text('Saved (${_savedWebsites.length})'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [_buildSearchTab(), _buildSavedWebsitesTab()],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 3D Interactive Hero Badge
              Center(
                child: ThreeDTiltCard(
                  maxTiltAngle: 0.28,
                  borderRadius: BorderRadius.circular(26),
                  glowColor: primaryColor,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryColor,
                          isDark
                              ? const Color(0xFF0051B3)
                              : const Color(0xFF0A84FF),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withAlpha(isDark ? 110 : 70),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.language_rounded,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Enter the website you want this app to load.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFF8E8E93)
                      : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),

              // Domain Input Widget
              DomainInput(
                controller: _domainController,
                enabled: !_isLoading,
                onSubmitted: (val) =>
                    _openWebsite(val, setAsDefault: _saveAsDefault),
              ),
              const SizedBox(height: 14),

              // Settings Container (Default Website + Biometric Lock)
              Material(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _saveAsDefault
                              ? primaryColor.withAlpha(isDark ? 40 : 25)
                              : isDark
                              ? const Color(0xFF2C2C2E)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.star_rounded,
                          size: 20,
                          color: _saveAsDefault
                              ? (isDark ? Colors.amber : Colors.amber.shade700)
                              : (isDark
                                    ? const Color(0xFF8E8E93)
                                    : const Color(0xFF9CA3AF)),
                        ),
                      ),
                      title: Text(
                        'Save as default website',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF111827),
                        ),
                      ),
                      subtitle: Text(
                        'Automatically open on next app launch',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF8E8E93)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                      value: _saveAsDefault,
                      onChanged: _isLoading
                          ? null
                          : (val) {
                              setState(() {
                                _saveAsDefault = val;
                              });
                            },
                    ),
                    Divider(
                      height: 1,
                      indent: 54,
                      color: isDark
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFF3F4F6),
                    ),
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isBiometricLockEnabled
                              ? const Color(0xFF10B981)
                                    .withAlpha(isDark ? 40 : 25)
                              : isDark
                              ? const Color(0xFF2C2C2E)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.fingerprint_rounded,
                          size: 20,
                          color: _isBiometricLockEnabled
                              ? const Color(0xFF10B981)
                              : (isDark
                                    ? const Color(0xFF8E8E93)
                                    : const Color(0xFF9CA3AF)),
                        ),
                      ),
                      title: Text(
                        'Biometric App Lock',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF111827),
                        ),
                      ),
                      subtitle: Text(
                        'Require Fingerprint / PIN on open',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF8E8E93)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                      value: _isBiometricLockEnabled,
                      onChanged: _isLoading
                          ? null
                          : (val) => _toggleBiometricLock(val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Launch Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () => _openWebsite(
                          _domainController.text,
                          setAsDefault: _saveAsDefault,
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.rocket_launch_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Save & Open Website',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 28),

              // Quick Suggestions Section
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: isDark
                        ? const Color(0xFF8E8E93)
                        : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Quick Suggestions',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFF8E8E93)
                          : const Color(0xFF6B7280),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickSuggestions.map((suggestion) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      _domainController.text = suggestion;
                      _openWebsite(suggestion, setAsDefault: _saveAsDefault);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2C2C2E)
                              : const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(isDark ? 20 : 5),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.link_rounded,
                            size: 14,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            suggestion,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavedWebsitesTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (_savedWebsites.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1C1C1E)
                      : const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bookmarks_outlined,
                  size: 56,
                  color: isDark
                      ? const Color(0xFF8E8E93)
                      : const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No Saved Websites Yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  'Every website you search or enter will be automatically saved here in local storage.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark
                        ? const Color(0xFF8E8E93)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _savedWebsites.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0, left: 4, right: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withAlpha(isDark ? 40 : 25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_savedWebsites.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Saved Websites',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _handleExportExcelCsv,
                      icon: const Icon(Icons.table_chart_rounded, size: 16),
                      label: const Text('Excel / CSV'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF10B981),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _handleClearAllSaved,
                      icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                      label: const Text('Clear All'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        final url = _savedWebsites[index - 1];
        final isDefault = url == _defaultUrl;
        final uri = Uri.tryParse(url);
        final host = uri?.host.isNotEmpty == true ? uri!.host : url;
        final firstLetter = host.isNotEmpty
            ? host.replaceFirst('www.', '')[0].toUpperCase()
            : 'W';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDefault
                    ? primaryColor
                    : isDark
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFE5E7EB),
                width: isDefault ? 1.6 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDefault
                      ? primaryColor
                      : isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    firstLetter,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDefault
                          ? Colors.white
                          : isDark
                          ? Colors.white70
                          : const Color(0xFF374151),
                    ),
                  ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      host,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isDefault)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Default',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Text(
                url,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? const Color(0xFF8E8E93)
                      : const Color(0xFF6B7280),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isDefault
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: isDefault
                          ? Colors.amber.shade700
                          : (isDark ? Colors.white54 : Colors.black38),
                      size: 22,
                    ),
                    tooltip: isDefault
                        ? 'Default Startup Website'
                        : 'Set as Default',
                    onPressed: () => _handleSetAsDefault(url),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    tooltip: 'Delete',
                    onPressed: () => _handleDeleteWebsite(url),
                  ),
                ],
              ),
              onTap: () => _openWebsite(url, setAsDefault: isDefault),
            ),
          ),
        );
      },
    );
  }
}
