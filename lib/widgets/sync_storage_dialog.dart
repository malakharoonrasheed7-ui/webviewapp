import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/permission_service.dart';
import '../services/storage_service.dart';
import 'three_d_tilt_card.dart';

class SyncStorageDialog extends StatefulWidget {
  final StorageService storageService;

  const SyncStorageDialog({super.key, required this.storageService});

  static Future<void> show(BuildContext context, {StorageService? storageService}) async {
    final service = storageService ?? StorageService();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SyncStorageDialog(storageService: service),
    );
  }

  @override
  State<SyncStorageDialog> createState() => _SyncStorageDialogState();
}

class _SyncStorageDialogState extends State<SyncStorageDialog> {
  String _currentPath = '';
  String? _customFolder;
  bool _autoSync = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSyncDetails();
  }

  Future<void> _loadSyncDetails() async {
    final path = await widget.storageService.getResolvedSyncFilePath();
    final customFolder = await widget.storageService.getCustomSyncFolder();
    final autoSync = await widget.storageService.isAutoSyncEnabled();
    if (mounted) {
      setState(() {
        _currentPath = path;
        _customFolder = customFolder;
        _autoSync = autoSync;
      });
    }
  }

  Future<void> _handlePickFolder() async {
    setState(() => _isSaving = true);
    try {
      final chosenFolder = await PermissionService.pickFolder();
      if (chosenFolder != null && chosenFolder.isNotEmpty) {
        await widget.storageService.setCustomSyncFolder(chosenFolder);
        await _loadSyncDetails();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.folder_special_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Sync location updated: $chosenFolder')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleResetToDefault() async {
    await widget.storageService.setCustomSyncFolder('');
    await _loadSyncDetails();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Reset to default Downloads folder.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleManualSyncNow() async {
    setState(() => _isSaving = true);
    await widget.storageService.writeAllHistoryToSyncFile();
    setState(() => _isSaving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('All search history & links synchronized to storage!'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF10B981),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              height: 5,
              width: 40,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF38383A) : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withAlpha(isDark ? 40 : 25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.sync_rounded, color: primaryColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto Storage Sync',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Data stays safe permanently across updates',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 3D Path Card
          ThreeDTiltCard(
            maxTiltAngle: 0.12,
            borderRadius: BorderRadius.circular(18),
            glowColor: primaryColor,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E7EB),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SAVED FILE LOCATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: primaryColor,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _currentPath));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('File path copied!'),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Icon(Icons.copy_rounded, size: 13, color: primaryColor),
                            const SizedBox(width: 4),
                            Text(
                              'Copy Path',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primaryColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentPath.isNotEmpty ? _currentPath : 'Resolving storage...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      color: isDark ? Colors.white70 : const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_user_rounded, size: 12, color: Color(0xFF10B981)),
                            SizedBox(width: 4),
                            Text(
                              'Excel (.CSV) Compatible',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_customFolder != null && _customFolder!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Custom Folder Active',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.amber),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Auto-Sync Toggle
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _autoSync ? const Color(0xFF10B981).withAlpha(25) : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.autorenew_rounded,
                color: _autoSync ? const Color(0xFF10B981) : (isDark ? Colors.white54 : Colors.black45),
                size: 20,
              ),
            ),
            title: const Text(
              'Automatic Real-time Sync',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Auto-appends every visited link & search in real-time',
              style: TextStyle(fontSize: 12),
            ),
            value: _autoSync,
            onChanged: (val) async {
              setState(() => _autoSync = val);
              await widget.storageService.setAutoSyncEnabled(val);
            },
          ),
          const SizedBox(height: 12),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _handlePickFolder,
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text('Change Folder'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (_customFolder != null && _customFolder!.isNotEmpty) ...[
                IconButton(
                  tooltip: 'Reset to Downloads Folder',
                  icon: const Icon(Icons.restart_alt_rounded),
                  onPressed: _handleResetToDefault,
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _handleManualSyncNow,
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sync_rounded, size: 18),
                  label: const Text('Sync Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
