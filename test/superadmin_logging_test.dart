import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/config/constants.dart';
import 'package:quickfix/models/user.dart';
import 'package:quickfix/models/system_log.dart';
import 'package:quickfix/models/approval_request.dart';

void main() {
  group('Superadmin Role Tests', () {
    test('Superadmin constants and priority work correctly', () {
      expect(Constants.roleSuperadmin, equals('superadmin'));
      expect(Constants.rolePriority[Constants.roleSuperadmin], equals(5));
      expect(Constants.roleDisplay[Constants.roleSuperadmin], equals('Super Admin'));
    });

    test('User model identifies superadmin and inherits admin permissions', () {
      final superadminUser = User(
        id: 'super-1',
        name: 'Super Admin User',
        email: 'superadmin@quickfix.com',
        role: Constants.roleSuperadmin,
      );

      final adminUser = User(
        id: 'admin-1',
        name: 'Admin User',
        email: 'admin@quickfix.com',
        role: Constants.roleAdmin,
      );

      expect(superadminUser.isSuperAdmin, isTrue);
      expect(superadminUser.isAdmin, isTrue);
      expect(superadminUser.hasPermission(Constants.roleAdmin), isTrue);

      expect(adminUser.isSuperAdmin, isFalse);
      expect(adminUser.isAdmin, isTrue);
      expect(adminUser.hasPermission(Constants.roleSuperadmin), isFalse);
    });
  });

  group('System Log Tests', () {
    test('SystemLog model serializes to and from map correctly', () {
      final now = DateTime.now();
      final log = SystemLog(
        id: 'log-100',
        userId: 'u-1',
        userName: 'Admin User',
        userRole: 'admin',
        action: 'DELETE_QUOTE',
        description: 'Deleted quotation QPN00005',
        details: '{"quoteId": "quote-5"}',
        timestamp: now,
        status: 'critical',
      );

      final map = log.toMap();
      expect(map['id'], equals('log-100'));
      expect(map['action'], equals('DELETE_QUOTE'));
      expect(map['status'], equals('critical'));

      final restored = SystemLog.fromMap(map);
      expect(restored.id, equals('log-100'));
      expect(restored.action, equals('DELETE_QUOTE'));
      expect(restored.status, equals('critical'));
    });
  });

  group('Approval Request Tests', () {
    test('ApprovalRequest model tracks pending, approved, and rejected states', () {
      final now = DateTime.now();
      final request = ApprovalRequest(
        id: 'req-1',
        requestedById: 'admin-1',
        requestedByName: 'Admin Bob',
        userRole: 'admin',
        actionType: 'DELETE_USER',
        targetId: 'user-99',
        targetSummary: 'Delete user John Doe (user-99)',
        details: 'Requires superadmin approval',
        status: 'pending',
        createdAt: now,
      );

      expect(request.isPending, isTrue);
      expect(request.isApproved, isFalse);
      expect(request.isRejected, isFalse);
      expect(request.actionDisplay, equals('Delete User Account'));

      final map = request.toMap();
      map['status'] = 'approved';
      map['resolved_by_name'] = 'Super Admin';

      final approvedReq = ApprovalRequest.fromMap(map);
      expect(approvedReq.isPending, isFalse);
      expect(approvedReq.isApproved, isTrue);
      expect(approvedReq.resolvedByName, equals('Super Admin'));
    });
  });
}
