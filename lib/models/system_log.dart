// lib/models/system_log.dart
import 'package:flutter/material.dart';
import 'package:quickfix/config/app_colors.dart';

class SystemLog {
  final String id;
  final String? userId;
  final String? userName;
  final String? userRole;
  final String action;
  final String description;
  final String? details;
  final DateTime timestamp;
  final String status; // 'info', 'warning', 'critical', 'pending_approval', 'approved', 'rejected'

  SystemLog({
    required this.id,
    this.userId,
    this.userName,
    this.userRole,
    required this.action,
    required this.description,
    this.details,
    required this.timestamp,
    this.status = 'info',
  });

  factory SystemLog.fromMap(Map<String, dynamic> map) {
    return SystemLog(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      userName: map['user_name']?.toString(),
      userRole: map['user_role']?.toString(),
      action: map['action']?.toString() ?? 'UNKNOWN',
      description: map['description']?.toString() ?? '',
      details: map['details']?.toString(),
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: map['status']?.toString() ?? 'info',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_role': userRole,
      'action': action,
      'description': description,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
    };
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'critical':
      case 'rejected':
        return AppColors.error;
      case 'warning':
      case 'pending_approval':
        return AppColors.warning;
      case 'approved':
        return AppColors.success;
      case 'info':
      default:
        return AppColors.info;
    }
  }

  IconData get actionIcon {
    final act = action.toUpperCase();
    if (act.contains('LOGIN') || act.contains('LOGOUT')) return Icons.vpn_key;
    if (act.contains('DELETE')) return Icons.delete_forever;
    if (act.contains('CREATE')) return Icons.add_circle;
    if (act.contains('UPDATE') || act.contains('EDIT')) return Icons.edit;
    if (act.contains('APPROVE')) return Icons.verified;
    if (act.contains('REJECT')) return Icons.cancel;
    if (act.contains('RESET')) return Icons.restart_alt;
    return Icons.history;
  }
}
