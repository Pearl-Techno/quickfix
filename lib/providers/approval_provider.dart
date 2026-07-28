// lib/providers/approval_provider.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/approval_request.dart';
import '../models/user.dart';
import '../services/database_helper.dart';
import '../services/log_service.dart';

class ApprovalProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final LogService _logService = LogService();
  final _uuid = const Uuid();

  List<ApprovalRequest> _requests = [];
  bool _isLoading = false;

  List<ApprovalRequest> get requests => _requests;
  List<ApprovalRequest> get pendingRequests =>
      _requests.where((r) => r.isPending).toList();
  bool get isLoading => _isLoading;
  int get pendingCount => pendingRequests.length;

  Future<void> loadRequests() async {
    _isLoading = true;
    notifyListeners();

    try {
      final rows = await _dbHelper.getApprovalRequests();
      _requests = rows.map((r) => ApprovalRequest.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Error loading approval requests: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<ApprovalRequest?> createRequest({
    required User requestedBy,
    required String actionType,
    String? targetId,
    required String targetSummary,
    String? details,
  }) async {
    try {
      final id = _uuid.v4();
      final request = ApprovalRequest(
        id: id,
        requestedById: requestedBy.id,
        requestedByName: requestedBy.name,
        userRole: requestedBy.role,
        actionType: actionType,
        targetId: targetId,
        targetSummary: targetSummary,
        details: details,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await _dbHelper.saveApprovalRequest(request.toMap());

      await _logService.logEvent(
        currentUser: requestedBy,
        action: 'CRITICAL_APPROVAL_REQUEST',
        description: 'Submitted approval request for $actionType ($targetSummary)',
        details: details,
        status: 'pending_approval',
      );

      await loadRequests();
      return request;
    } catch (e) {
      debugPrint('Error creating approval request: $e');
      return null;
    }
  }

  Future<bool> approveRequest(
    String id,
    User superadmin, {
    Future<void> Function()? onApprovedAction,
  }) async {
    try {
      if (onApprovedAction != null) {
        await onApprovedAction();
      }

      final updateData = {
        'status': 'approved',
        'resolved_at': DateTime.now().toIso8601String(),
        'resolved_by_id': superadmin.id,
        'resolved_by_name': superadmin.name,
      };

      await _dbHelper.updateApprovalRequest(id, updateData);

      final req = _requests.firstWhere((r) => r.id == id, orElse: () => ApprovalRequest(
        id: id,
        requestedById: '',
        requestedByName: '',
        userRole: '',
        actionType: 'ACTION',
        targetSummary: '',
        createdAt: DateTime.now(),
      ));

      await _logService.logEvent(
        currentUser: superadmin,
        action: 'CRITICAL_APPROVAL_APPROVED',
        description: 'Superadmin approved: ${req.actionDisplay} (${req.targetSummary})',
        details: 'Approved by ${superadmin.name}',
        status: 'approved',
      );

      await loadRequests();
      return true;
    } catch (e) {
      debugPrint('Error approving request: $e');
      return false;
    }
  }

  Future<bool> rejectRequest(
    String id,
    User superadmin, {
    String? reason,
  }) async {
    try {
      final updateData = {
        'status': 'rejected',
        'resolved_at': DateTime.now().toIso8601String(),
        'resolved_by_id': superadmin.id,
        'resolved_by_name': superadmin.name,
        'rejection_reason': reason ?? 'Rejected by Superadmin',
      };

      await _dbHelper.updateApprovalRequest(id, updateData);

      final req = _requests.firstWhere((r) => r.id == id, orElse: () => ApprovalRequest(
        id: id,
        requestedById: '',
        requestedByName: '',
        userRole: '',
        actionType: 'ACTION',
        targetSummary: '',
        createdAt: DateTime.now(),
      ));

      await _logService.logEvent(
        currentUser: superadmin,
        action: 'CRITICAL_APPROVAL_REJECTED',
        description: 'Superadmin rejected: ${req.actionDisplay} (${req.targetSummary})',
        details: 'Reason: ${reason ?? "None specified"}',
        status: 'rejected',
      );

      await loadRequests();
      return true;
    } catch (e) {
      debugPrint('Error rejecting request: $e');
      return false;
    }
  }
}
