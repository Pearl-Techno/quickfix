// lib/widgets/sync_refresh_button.dart
import 'package:flutter/material.dart';
import 'package:quickfix/services/database_service.dart';

class SyncRefreshButton extends StatefulWidget {
  final Color? color;
  const SyncRefreshButton({super.key, this.color});

  @override
  State<SyncRefreshButton> createState() => _SyncRefreshButtonState();
}

class _SyncRefreshButtonState extends State<SyncRefreshButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  final DatabaseService _dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
    // Premium rotation speed and controller setup
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _dbService.isSyncingNotifier.addListener(_onSyncStateChanged);
    if (_dbService.isSyncingNotifier.value) {
      _rotationController.repeat();
    }
  }

  void _onSyncStateChanged() {
    if (_dbService.isSyncingNotifier.value) {
      _rotationController.repeat();
    } else {
      _rotationController.stop();
      _rotationController.reset();
    }
  }

  @override
  void dispose() {
    _dbService.isSyncingNotifier.removeListener(_onSyncStateChanged);
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _handleSync() async {
    try {
      final isOnline = await _dbService.isOnline;
      if (!mounted) return;
      if (!isOnline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📴 You are offline. Changes will sync automatically when connection is restored.'),
            backgroundColor: Colors.amber,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔄 Starting manual synchronization...'),
          backgroundColor: Colors.blueAccent,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );

      await _dbService.syncNow();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Data successfully synchronized and refreshed!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Sync failed: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _dbService.isSyncingNotifier,
      builder: (context, isSyncing, child) {
        return ValueListenableBuilder<int>(
          valueListenable: _dbService.pendingSyncCountNotifier,
          builder: (context, pendingCount, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                RotationTransition(
                  turns: _rotationController,
                  child: IconButton(
                     icon: const Icon(Icons.sync),
                     color: widget.color,
                     tooltip: 'Sync & Refresh Data',
                     onPressed: isSyncing ? null : _handleSync,
                  ),
                ),
                if (pendingCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.amber[800],
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
