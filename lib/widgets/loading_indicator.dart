import 'package:flutter/material.dart';
import 'three_d_loader.dart';

/// Next-gen Loading Indicator with 3D Holographic orbiting rings & glowing core.
class LoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;
  final bool use3D;

  const LoadingIndicator({
    super.key,
    this.message,
    this.size = 64.0,
    this.use3D = true,
  });

  @override
  Widget build(BuildContext context) {
    if (use3D) {
      return ThreeDLoader(
        message: message,
        size: size,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFE5E7EB),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 40 : 10),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              width: size * 0.5,
              height: size * 0.5,
              child: CircularProgressIndicator(
                strokeWidth: 2.8,
                strokeCap: StrokeCap.round,
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFE5E7EB)
                    : const Color(0xFF374151),
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
