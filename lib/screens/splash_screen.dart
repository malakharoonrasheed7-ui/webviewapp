import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../services/auth_service.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../widgets/loading_indicator.dart';

class SplashScreen extends StatefulWidget {
  final StorageService? storageService;
  final AuthService? authService;

  const SplashScreen({super.key, this.storageService, this.authService});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final StorageService _storageService;
  late final AuthService _authService;
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  bool _isLocked = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _storageService = widget.storageService ?? StorageService();
    _authService = widget.authService ?? AuthService();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();
    _checkSecurityAndProceed();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkSecurityAndProceed() async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Request all device runtime permissions upfront
    try {
      await PermissionService.requestAllPermissions();
    } catch (_) {}

    if (!mounted) return;

    final isLockEnabled = await _authService.isBiometricLockEnabled();
    if (isLockEnabled) {
      final success = await _authService.authenticate(
        reason: 'Please authenticate to open ${AppConstants.appName}',
      );

      if (!mounted) return;

      if (!success) {
        setState(() {
          _isLocked = true;
        });
        return;
      }
    }

    _navigateToNextScreen();
  }

  Future<void> _unlockWithBiometrics() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
    });

    final success = await _authService.authenticate(
      reason: 'Please authenticate to open ${AppConstants.appName}',
    );

    if (!mounted) return;

    setState(() {
      _isAuthenticating = false;
    });

    if (success) {
      _navigateToNextScreen();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.lock_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Authentication failed. Please try again.'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade600,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _navigateToNextScreen() async {
    final savedUrl = await _storageService.getWebsiteUrl();

    if (!mounted) return;

    if (savedUrl != null && savedUrl.isNotEmpty) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.webview,
        arguments: savedUrl,
      );
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.setup);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF000000)
          : const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 3D Animated Floating App Icon with Orbital Aura
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0018)
                          ..rotateY((1 - _animController.value) * 0.4)
                          ..rotateX((1 - _animController.value) * 0.2),
                        child: Container(
                          width: 96,
                          height: 96,
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
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withAlpha(isDark ? 120 : 80),
                                blurRadius: 30,
                                spreadRadius: 2,
                                offset: const Offset(0, 10),
                              ),
                              BoxShadow(
                                color: (isDark
                                        ? const Color(0xFF38BDF8)
                                        : const Color(0xFF6366F1))
                                    .withAlpha(isDark ? 80 : 40),
                                blurRadius: 40,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isLocked ? Icons.lock_rounded : Icons.language_rounded,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  Text(
                    AppConstants.appName,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1C1C1E)
                          : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2C2C2E)
                            : const Color(0xFFD1D5DB),
                      ),
                    ),
                    child: Text(
                      'v${AppConstants.appVersion}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFF8E8E93)
                            : const Color(0xFF4B5563),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  if (_isLocked) ...[
                    ElevatedButton.icon(
                      onPressed: _unlockWithBiometrics,
                      icon: const Icon(Icons.fingerprint_rounded, size: 22),
                      label: const Text('Unlock App'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ] else ...[
                    const LoadingIndicator(size: 64, use3D: true),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
