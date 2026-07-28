// lib/screens/admin/system_logs_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/log_provider.dart';
import '../../models/system_log.dart';
import '../../widgets/sidebar_menu.dart';
import '../../widgets/loading_spinner.dart';
import '../../utils/helpers.dart';

class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LogProvider>().loadLogs();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logProvider = context.watch<LogProvider>();
    final authProvider = context.watch<AuthProvider>();
    final logs = logProvider.logs;

    final criticalCount = logs.where((l) => l.status == 'critical' || l.status == 'rejected').length;
    final warningCount = logs.where((l) => l.status == 'warning' || l.status == 'pending_approval').length;
    final infoCount = logs.where((l) => l.status == 'info' || l.status == 'approved').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.receipt_long_outlined, color: Colors.white),
            SizedBox(width: 10),
            Text('System Audit Logs', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => logProvider.loadLogs(),
            tooltip: 'Refresh Logs',
          ),
          if (authProvider.currentUser?.isSuperAdmin == true)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () => _confirmClearLogs(context, logProvider, authProvider),
              tooltip: 'Clear Logs',
            ),
        ],
      ),
      drawer: const SidebarMenu(selectedIndex: 12),
      body: Column(
        children: [
          // Filter & Search Header Card
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => logProvider.setSearchQuery(value),
                        decoration: InputDecoration(
                          hintText: 'Search logs by user, action, description...',
                          prefixIcon: const Icon(Icons.search, color: AppColors.textLight),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    logProvider.setSearchQuery('');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          filled: true,
                          fillColor: AppColors.background,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButton<String?>(
                          value: logProvider.selectedStatus,
                          hint: const Text('All Statuses', style: TextStyle(fontSize: 13)),
                          icon: const Icon(Icons.filter_list, size: 20, color: AppColors.primary),
                          onChanged: (status) => logProvider.setStatusFilter(status),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('All Statuses')),
                            DropdownMenuItem(value: 'info', child: Text('Info')),
                            DropdownMenuItem(value: 'warning', child: Text('Warning')),
                            DropdownMenuItem(value: 'critical', child: Text('Critical')),
                            DropdownMenuItem(value: 'pending_approval', child: Text('Pending Approval')),
                            DropdownMenuItem(value: 'approved', child: Text('Approved')),
                            DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Stats Chips
                Row(
                  children: [
                    _buildStatChip('Total: ${logs.length}', AppColors.primary),
                    const SizedBox(width: 8),
                    _buildStatChip('Info: $infoCount', AppColors.info),
                    const SizedBox(width: 8),
                    _buildStatChip('Warnings: $warningCount', AppColors.warning),
                    const SizedBox(width: 8),
                    _buildStatChip('Critical: $criticalCount', AppColors.error),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Log List View
          Expanded(
            child: logProvider.isLoading
                ? const LoadingSpinner(message: 'Loading system logs...')
                : logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_outlined, size: 64, color: AppColors.textLight.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            const Text(
                              'No system logs found',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Activity and audit trails will appear here automatically.',
                              style: TextStyle(fontSize: 13, color: AppColors.textLight),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          return _buildLogCard(context, log);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildLogCard(BuildContext context, SystemLog log) {
    final formattedTime = DateFormat('MMM dd, yyyy • HH:mm:ss').format(log.timestamp);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: log.statusColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(log.actionIcon, color: log.statusColor, size: 20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                log.action,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                log.description,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 13, color: AppColors.textLight),
              const SizedBox(width: 4),
              Text(
                '${log.userName ?? "System"} (${log.userRole ?? "system"})',
                style: TextStyle(fontSize: 11, color: AppColors.textLight),
              ),
              const Spacer(),
              Icon(Icons.access_time, size: 13, color: AppColors.textLight),
              const SizedBox(width: 4),
              Text(
                formattedTime,
                style: TextStyle(fontSize: 11, color: AppColors.textLight),
              ),
            ],
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Log ID', log.id),
                _buildDetailRow('Timestamp', formattedTime),
                _buildDetailRow('User ID', log.userId ?? 'N/A'),
                _buildDetailRow('User Role', log.userRole ?? 'N/A'),
                _buildDetailRow('Status', log.status.toUpperCase()),
                if (log.details != null && log.details!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Details / Payload:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SelectableText(
                      log.details!,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 11, color: AppColors.text)),
          ),
        ],
      ),
    );
  }

  void _confirmClearLogs(BuildContext context, LogProvider logProvider, AuthProvider authProvider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear All System Logs'),
        content: const Text('Are you sure you want to delete all system audit logs? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Clear Logs'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await logProvider.clearAllLogs();
      if (!context.mounted) return;
      Helpers.showSnackBar(context, 'System logs cleared successfully');
    }
  }
}
