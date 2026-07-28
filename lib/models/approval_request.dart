// lib/models/approval_request.dart
import 'package:flutter/material.dart';
import 'package:quickfix/config/app_colors.dart';

class ApprovalRequest {
  final String id;
  final String requestedById;
  final String requestedByName;
  final String userRole;
  final String actionType; // e.g. 'DELETE_USER', 'DELETE_QUOTE', 'DELETE_INVOICE', 'RESET_DATABASE', 'CHANGE_ROLE'
  final String? targetId;
  final String targetSummary;
  final String? details;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedById;
  final String? resolvedByName;
  final String? rejectionReason;

  ApprovalRequest({
    required this.id,
    required this.requestedById,
    required this.requestedByName,
    required this.userRole,
    required this.actionType,
    this.targetId,
    required this.targetSummary,
    this.details,
    this.status = 'pending',
    required this.createdAt,
    this.resolvedAt,
    this.resolvedById,
    this.resolvedByName,
    this.rejectionReason,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory ApprovalRequest.fromMap(Map<String, dynamic> map) {
    return ApprovalRequest(
      id: map['id']?.toString() ?? '',
      requestedById: map['requested_by_id']?.toString() ?? '',
      requestedByName: map['requested_by_name']?.toString() ?? 'Admin',
      userRole: map['user_role']?.toString() ?? 'admin',
      actionType: map['action_type']?.toString() ?? 'CRITICAL_ACTION',
      targetId: map['target_id']?.toString(),
      targetSummary: map['target_summary']?.toString() ?? '',
      details: map['details']?.toString(),
      status: map['status']?.toString() ?? 'pending',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      resolvedAt: map['resolved_at'] != null
          ? DateTime.tryParse(map['resolved_at'].toString())
          : null,
      resolvedById: map['resolved_by_id']?.toString(),
      resolvedByName: map['resolved_by_name']?.toString(),
      rejectionReason: map['rejection_reason']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requested_by_id': requestedById,
      'requested_by_name': requestedByName,
      'user_role': userRole,
      'action_type': actionType,
      'target_id': targetId,
      'target_summary': targetSummary,
      'details': details,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'resolved_by_id': resolvedById,
      'resolved_by_name': resolvedByName,
      'rejection_reason': rejectionReason,
    };
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'pending':
      default:
        return AppColors.warning;
    }
  }

  String get actionDisplay {
    switch (actionType) {
      case 'DELETE_USER':
        return 'Delete User Account';
      case 'DELETE_QUOTE':
        return 'Delete Quotation';
      case 'DELETE_INVOICE':
        return 'Delete Invoice';
      case 'DELETE_PRODUCT':
        return 'Delete Inventory Product';
      case 'RESET_DATABASE':
        return 'Reset Database for Production';
      case 'CHANGE_ROLE':
        return 'Promote/Modify User Role';
      default:
        return actionType.replaceAll('_', ' ');
    }
  }
}
