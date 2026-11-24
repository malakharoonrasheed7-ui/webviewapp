import 'package:flutter/material.dart';

/// An interactive 3D Tilt Card that reacts to touch gestures with realistic 3D perspective rotation,
/// dynamic specular shine, and depth elevation.
class ThreeDTiltCard extends StatefulWidget {
  final Widget child;
  final double maxTiltAngle;
  final BorderRadius? borderRadius;
  final Color? glowColor;
  final VoidCallback? onTap;

  const ThreeDTiltCard({
    super.key,
    required this.child,
    this.maxTiltAngle = 0.16,
    this.borderRadius,
    this.glowColor,
    this.onTap,
  });

  @override
  State<ThreeDTiltCard> createState() => _ThreeDTiltCardState();
}

class _ThreeDTiltCardState extends State<ThreeDTiltCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _resetController;
  late Animation<double> _tiltXAnimation;
  late Animation<double> _tiltYAnimation;

  double _tiltX = 0.0;
  double _tiltY = 0.0;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..addListener(() {
        setState(() {
          _tiltX = _tiltXAnimation.value;
          _tiltY = _tiltYAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _handlePanUpdate(DragUpdateDetails details, Size size) {
    if (size.width == 0 || size.height == 0) return;

    final localPos = details.localPosition;
    final normalizedX = (localPos.dx / size.width - 0.5) * 2; // -1 to 1
    final normalizedY = (localPos.dy / size.height - 0.5) * 2; // -1 to 1

    setState(() {
      _tiltY = normalizedX.clamp(-1.0, 1.0) * widget.maxTiltAngle;
      _tiltX = -normalizedY.clamp(-1.0, 1.0) * widget.maxTiltAngle;
      _isHovered = true;
    });
  }

  void _resetTilt() {
    _tiltXAnimation = Tween<double>(
      begin: _tiltX,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic));
    _tiltYAnimation = Tween<double>(
      begin: _tiltY,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic));

    _resetController.forward(from: 0.0);
    setState(() {
      _isHovered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glow = widget.glowColor ?? theme.colorScheme.primary;
    final radius = widget.borderRadius ?? BorderRadius.circular(24);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          onTap: widget.onTap,
          onPanDown: (d) => _resetController.stop(),
          onPanUpdate: (d) => _handlePanUpdate(d, size),
          onPanEnd: (_) => _resetTilt(),
          onPanCancel: () => _resetTilt(),
          child: Transform(
            alignment: FractionalOffset.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015) // 3D perspective depth
              ..rotateX(_tiltX)
              ..rotateY(_tiltY)
              ..scaleByDouble(
                _isHovered ? 1.02 : 1.0,
                _isHovered ? 1.02 : 1.0,
                1.0,
                1.0,
              ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: glow.withAlpha(isDark ? (_isHovered ? 80 : 35) : (_isHovered ? 50 : 20)),
                    blurRadius: _isHovered ? 28 : 16,
                    offset: Offset(_tiltY * 30, -_tiltX * 30 + 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 60 : 15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  children: [
                    widget.child,

                    // Specular 3D Holographic Light Sheen
                    if (_isHovered)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(-_tiltY * 4 - 0.5, -_tiltX * 4 - 0.5),
                                end: Alignment(_tiltY * 4 + 0.5, _tiltX * 4 + 0.5),
                                colors: [
                                  Colors.white.withAlpha(45),
                                  Colors.white.withAlpha(0),
                                  glow.withAlpha(25),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
