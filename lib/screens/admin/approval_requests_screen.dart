// lib/screens/admin/approval_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../models/approval_request.dart';
import '../../providers/approval_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/sidebar_menu.dart';
import '../../widgets/loading_spinner.dart';
import '../../utils/helpers.dart';

class ApprovalRequestsScreen extends StatefulWidget {
  const ApprovalRequestsScreen({super.key});

  @override
  State<ApprovalRequestsScreen> createState() => _ApprovalRequestsScreenState();
}

class _ApprovalRequestsScreenState extends State<ApprovalRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ApprovalProvider>().loadRequests();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final approvalProvider = context.watch<ApprovalProvider>();
    final authProvider = context.watch<AuthProvider>();
    final pendingRequests = approvalProvider.requests.where((r) => r.isPending).toList();
    final resolvedRequests = approvalProvider.requests.where((r) => !r.isPending).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.verified_user_outlined, color: Colors.white),
            SizedBox(width: 10),
            Text('Superadmin Approvals', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => approvalProvider.loadRequests(),
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Pending Approvals'),
                  if (pendingRequests.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${pendingRequests.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(text: 'Resolved (${resolvedRequests.length})'),
          ],
        ),
      ),
      drawer: const SidebarMenu(selectedIndex: 13),
      body: approvalProvider.isLoading
          ? const LoadingSpinner(message: 'Loading approval requests...')
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRequestList(context, pendingRequests, isPendingTab: true, authProvider: authProvider),
                _buildRequestList(context, resolvedRequests, isPendingTab: false, authProvider: authProvider),
              ],
            ),
    );
  }

  Widget _buildRequestList(
    BuildContext context,
    List<ApprovalRequest> requests, {
    required bool isPendingTab,
    required AuthProvider authProvider,
  }) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPendingTab ? Icons.check_circle_outline : Icons.history,
              size: 64,
              color: AppColors.textLight.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              isPendingTab ? 'No pending approval requests' : 'No resolved requests found',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
            ),
            const SizedBox(height: 8),
            Text(
              isPendingTab
                  ? 'Critical actions initiated by admins will show up here for your approval.'
                  : 'Past approved or rejected requests will be listed here.',
              style: TextStyle(fontSize: 13, color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        return _buildRequestCard(context, req, isPendingTab: isPendingTab, authProvider: authProvider);
      },
    );
  }

  Widget _buildRequestCard(
    BuildContext context,
    ApprovalRequest req, {
    required bool isPendingTab,
    required AuthProvider authProvider,
  }) {
    final approvalProvider = context.read<ApprovalProvider>();
    final formattedTime = DateFormat('MMM dd, yyyy • HH:mm').format(req.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: req.statusColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Action Type Badge & Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    req.actionDisplay,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: req.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: req.statusColor),
                  ),
                  child: Text(
                    req.status.toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: req.statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Target Summary & Details
            Text(
              req.targetSummary,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text),
            ),
            if (req.details != null && req.details!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                req.details!,
                style: TextStyle(fontSize: 13, color: AppColors.textLight),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Request Metadata
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: AppColors.textLight),
                const SizedBox(width: 4),
                Text(
                  'Requested by: ${req.requestedByName} (${req.userRole})',
                  style: TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Icon(Icons.access_time, size: 14, color: AppColors.textLight),
                const SizedBox(width: 4),
                Text(
                  formattedTime,
                  style: TextStyle(fontSize: 12, color: AppColors.textLight),
                ),
              ],
            ),

            if (!req.isPending) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resolved by ${req.resolvedByName ?? "Superadmin"} on ${req.resolvedAt != null ? DateFormat("MMM dd, yyyy HH:mm").format(req.resolvedAt!) : "N/A"}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    if (req.isRejected && req.rejectionReason != null)
                      Text(
                        'Reason: ${req.rejectionReason}',
                        style: TextStyle(fontSize: 11, color: AppColors.error),
                      ),
                  ],
                ),
              ),
            ],

            // Action Buttons for Pending Requests (Superadmin only)
            if (isPendingTab) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _handleReject(context, approvalProvider, authProvider, req),
                      icon: const Icon(Icons.close, color: AppColors.error, size: 18),
                      label: const Text('Reject', style: TextStyle(color: AppColors.error)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleApprove(context, approvalProvider, authProvider, req),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleApprove(
    BuildContext context,
    ApprovalProvider approvalProvider,
    AuthProvider authProvider,
    ApprovalRequest req,
  ) async {
    final superadmin = authProvider.currentUser;
    if (superadmin == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Approve ${req.actionDisplay}'),
        content: Text('Are you sure you want to approve this action?\n\nTarget: ${req.targetSummary}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await approvalProvider.approveRequest(
        req.id,
        superadmin,
      );
      if (!context.mounted) return;
      if (success) {
        Helpers.showSnackBar(context, 'Request approved successfully', backgroundColor: AppColors.success);
      } else {
        Helpers.showSnackBar(context, 'Failed to approve request', backgroundColor: AppColors.error);
      }
    }
  }

  void _handleReject(
    BuildContext context,
    ApprovalProvider approvalProvider,
    AuthProvider authProvider,
    ApprovalRequest req,
  ) async {
    final superadmin = authProvider.currentUser;
    if (superadmin == null) return;

    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Reject ${req.actionDisplay}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Provide a reason for rejecting this request: (${req.targetSummary})'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject Request'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final reason = reasonController.text.trim();
      final success = await approvalProvider.rejectRequest(
        req.id,
        superadmin,
        reason: reason.isNotEmpty ? reason : 'Rejected by Superadmin',
      );
      reasonController.dispose();
      if (!context.mounted) return;
      if (success) {
        Helpers.showSnackBar(context, 'Request rejected', backgroundColor: AppColors.warning);
      } else {
        Helpers.showSnackBar(context, 'Failed to reject request', backgroundColor: AppColors.error);
      }
    }
  }
}
