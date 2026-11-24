import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A high-performance, futuristic 3D Holographic Loader with rotating orbital rings,
/// pulsating core sphere, and depth shadow projection.
class ThreeDLoader extends StatefulWidget {
  final String? message;
  final double size;
  final Color? primaryColor;
  final Color? accentColor;

  const ThreeDLoader({
    super.key,
    this.message,
    this.size = 90.0,
    this.primaryColor,
    this.accentColor,
  });

  @override
  State<ThreeDLoader> createState() => _ThreeDLoaderState();
}

class _ThreeDLoaderState extends State<ThreeDLoader>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.82, end: 1.14).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = widget.primaryColor ?? theme.colorScheme.primary;
    final accent =
        widget.accentColor ??
        (isDark ? const Color(0xFF38BDF8) : const Color(0xFF6366F1));

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.size * 1.5,
            height: widget.size * 1.5,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _rotationController,
                _pulseAnimation,
              ]),
              builder: (context, child) {
                final angle = _rotationController.value * 2 * math.pi;
                final pulse = _pulseAnimation.value;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Floor shadow with dynamic 3D depth pulsing
                    Positioned(
                      bottom: widget.size * 0.08,
                      child: Container(
                        width: widget.size * 0.9 * pulse,
                        height: widget.size * 0.22,
                        decoration: BoxDecoration(
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.all(
                            Radius.elliptical(
                              widget.size * 0.45,
                              widget.size * 0.11,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withAlpha(isDark ? 80 : 45),
                              blurRadius: 18 * pulse,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Outer 3D Ring (Pitch: 65 deg, Yaw: continuous)
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.002)
                        ..rotateX(1.1)
                        ..rotateZ(angle),
                      child: Container(
                        width: widget.size * 1.35,
                        height: widget.size * 1.35,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            width: 3.2,
                            color: Colors.transparent,
                          ),
                          gradient: SweepGradient(
                            colors: [
                              primary.withAlpha(0),
                              primary,
                              accent,
                              primary.withAlpha(0),
                            ],
                            stops: const [0.0, 0.45, 0.75, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withAlpha(isDark ? 110 : 60),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Middle 3D Ring (Counter-rotating, Cross-axis: -55 deg)
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.002)
                        ..rotateX(-0.95)
                        ..rotateY(0.4)
                        ..rotateZ(-angle * 1.3),
                      child: Container(
                        width: widget.size * 1.1,
                        height: widget.size * 1.1,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            width: 2.6,
                            color: Colors.transparent,
                          ),
                          gradient: SweepGradient(
                            colors: [
                              accent.withAlpha(0),
                              accent,
                              primary,
                              accent.withAlpha(0),
                            ],
                            stops: const [0.0, 0.5, 0.85, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withAlpha(isDark ? 90 : 50),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Floating 3D Glowing Core Sphere
                    Transform.scale(
                      scale: pulse,
                      child: Container(
                        width: widget.size * 0.46,
                        height: widget.size * 0.46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: const Alignment(-0.35, -0.35),
                            radius: 0.9,
                            colors: [
                              Colors.white,
                              accent,
                              primary,
                              isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFF1E1B4B),
                            ],
                            stops: const [0.0, 0.35, 0.7, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withAlpha(isDark ? 180 : 120),
                              blurRadius: 20 * pulse,
                              spreadRadius: 3 * pulse,
                            ),
                            BoxShadow(
                              color: accent.withAlpha(isDark ? 140 : 80),
                              blurRadius: 32,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.language_rounded,
                            size: widget.size * 0.22,
                            color: Colors.white.withAlpha(220),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          if (widget.message != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1C1C1E).withAlpha(180)
                    : Colors.white.withAlpha(220),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFE5E7EB),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 50 : 15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                widget.message!,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
