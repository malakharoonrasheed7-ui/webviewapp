import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DomainInput extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onChanged;

  const DomainInput({
    super.key,
    required this.controller,
    this.enabled = true,
    this.onSubmitted,
    this.onChanged,
  });

  @override
  State<DomainInput> createState() => _DomainInputState();
}

class _DomainInputState extends State<DomainInput> {
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
  }

  void _onFocusChange() {
    setState(() {
      _hasFocus = _focusNode.hasFocus;
    });
  }

  void _onTextChange() {
    setState(() {});
    widget.onChanged?.call();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      widget.controller.text = data.text!.trim();
      widget.controller.selection = TextSelection.fromPosition(
        TextPosition(offset: widget.controller.text.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final hasText = widget.controller.text.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _hasFocus
              ? primaryColor
              : isDark
              ? const Color(0xFF38383A)
              : const Color(0xFFE5E7EB),
          width: _hasFocus ? 1.8 : 1.2,
        ),
        boxShadow: [
          if (_hasFocus)
            BoxShadow(
              color: primaryColor.withAlpha(isDark ? 50 : 35),
              blurRadius: 12,
              offset: const Offset(0, 2),
            )
          else
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 30 : 8),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.go,
        autocorrect: false,
        enableSuggestions: false,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF111827),
          letterSpacing: -0.2,
        ),
        onSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          labelText: 'Website',
          hintText: 'example.com or https://...',
          hintStyle: TextStyle(
            color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF9CA3AF),
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
          labelStyle: TextStyle(
            color: _hasFocus
                ? primaryColor
                : isDark
                ? const Color(0xFF8E8E93)
                : const Color(0xFF6B7280),
            fontSize: 14,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _hasFocus
                        ? primaryColor.withAlpha(isDark ? 40 : 25)
                        : isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.language_rounded,
                    size: 18,
                    color: _hasFocus
                        ? primaryColor
                        : isDark
                        ? const Color(0xFF98989D)
                        : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'https://',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: primaryColor.withAlpha(180),
                  ),
                ),
              ],
            ),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasText)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF3A3A3C)
                          : const Color(0xFFE5E7EB),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  tooltip: 'Clear',
                  onPressed: widget.enabled
                      ? () {
                          widget.controller.clear();
                          setState(() {});
                        }
                      : null,
                )
              else
                IconButton(
                  icon: Icon(
                    Icons.content_paste_rounded,
                    size: 18,
                    color: isDark
                        ? const Color(0xFF8E8E93)
                        : const Color(0xFF6B7280),
                  ),
                  tooltip: 'Paste from clipboard',
                  onPressed: widget.enabled ? _pasteFromClipboard : null,
                ),
              const SizedBox(width: 4),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
