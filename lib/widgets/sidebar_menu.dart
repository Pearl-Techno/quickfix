import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../config/routes.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../utils/helpers.dart';

class SidebarMenu extends StatelessWidget {
  final int selectedIndex;
  final Function(int)? onItemSelected;

  const SidebarMenu({
    super.key,
    required this.selectedIndex,
    this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    return Drawer(
      width: 320,
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 30,
              offset: Offset(4, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // Premium Header
            _buildPremiumHeader(context, currentUser),
            const SizedBox(height: 8),
            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  // Dashboard
                  _buildNavItem(
                    icon: Icons.space_dashboard_outlined,
                    activeIcon: Icons.space_dashboard,
                    title: 'Dashboard',
                    index: 0,
                    isSelected: selectedIndex == 0,
                    onTap: () => _handleItemTap(context, 0),
                  ),
                  const SizedBox(height: 4),
                  _buildDivider(),
                  const SizedBox(height: 4),

                  // Management Section
                  _buildSectionHeader('MANAGEMENT'),
                  _buildNavItem(
                    icon: Icons.receipt_long_outlined,
                    activeIcon: Icons.receipt_long,
                    title: 'Quotations',
                    index: 1,
                    isSelected: selectedIndex == 1,
                    onTap: () => _handleItemTap(context, 1),
                    badge: 'New',
                  ),
                  _buildNavItem(
                    icon: Icons.people_outline,
                    activeIcon: Icons.people,
                    title: 'Customers',
                    index: 2,
                    isSelected: selectedIndex == 2,
                    onTap: () => _handleItemTap(context, 2),
                  ),
                  _buildNavItem(
                    icon: Icons.inventory_2_outlined,
                    activeIcon: Icons.inventory_2,
                    title: 'Inventory',
                    index: 3,
                    isSelected: selectedIndex == 3,
                    onTap: () => _handleItemTap(context, 3),
                  ),
                  _buildNavItem(
                    icon: Icons.price_change_outlined,
                    activeIcon: Icons.price_change,
                    title: 'Price List',
                    index: 10,
                    isSelected: selectedIndex == 10,
                    onTap: () => _handleItemTap(context, 10),
                  ),
                  _buildNavItem(
                    icon: Icons.receipt_outlined,
                    activeIcon: Icons.receipt,
                    title: 'Invoices',
                    index: 4,
                    isSelected: selectedIndex == 4,
                    onTap: () => _handleItemTap(context, 4),
                  ),
                  if (authProvider.canViewReports)
                    _buildNavItem(
                      icon: Icons.bar_chart_outlined,
                      activeIcon: Icons.bar_chart,
                      title: 'Reports & Analytics',
                      index: 11,
                      isSelected: selectedIndex == 11,
                      onTap: () => _handleItemTap(context, 11),
                    ),
                  if (authProvider.currentUser?.isAdmin == true) ...[
                    const SizedBox(height: 8),
                    _buildDivider(),
                    const SizedBox(height: 8),
                    _buildSectionHeader('SYSTEM AUDIT'),
                    _buildNavItem(
                      icon: Icons.receipt_long_outlined,
                      activeIcon: Icons.receipt_long,
                      title: 'System Logs',
                      index: 12,
                      isSelected: selectedIndex == 12,
                      onTap: () => _handleItemTap(context, 12),
                    ),
                    _buildNavItem(
                      icon: Icons.verified_user_outlined,
                      activeIcon: Icons.verified_user,
                      title: 'Approvals',
                      index: 13,
                      isSelected: selectedIndex == 13,
                      onTap: () => _handleItemTap(context, 13),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _buildDivider(),
                  const SizedBox(height: 8),

                  // Field Work Section
                  _buildSectionHeader('FIELD WORK'),
                  _buildNavItem(
                    icon: Icons.add_location_alt_outlined,
                    activeIcon: Icons.add_location_alt,
                    title: 'Site Quote',
                    index: 5,
                    isSelected: selectedIndex == 5,
                    onTap: () => _handleItemTap(context, 5),
                  ),
                  _buildNavItem(
                    icon: Icons.straighten_outlined,
                    activeIcon: Icons.straighten,
                    title: 'Measurements',
                    index: 6,
                    isSelected: selectedIndex == 6,
                    onTap: () => _handleItemTap(context, 6),
                  ),
                  _buildNavItem(
                    icon: Icons.list_alt_outlined,
                    activeIcon: Icons.list_alt,
                    title: 'My Quotes',
                    index: 7,
                    isSelected: selectedIndex == 7,
                    onTap: () => _handleItemTap(context, 7),
                  ),
                  const SizedBox(height: 8),
                  _buildDivider(),
                  const SizedBox(height: 4),

                  // Settings & Logout
                  _buildNavItem(
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings,
                    title: 'Settings',
                    index: 8,
                    isSelected: selectedIndex == 8,
                    onTap: () => _handleItemTap(context, 8),
                  ),
                  _buildNavItem(
                    icon: Icons.logout_outlined,
                    activeIcon: Icons.logout,
                    title: 'Logout',
                    index: 9,
                    isSelected: selectedIndex == 9,
                    onTap: () => _handleItemTap(context, 9),
                    isLogout: true,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            // Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ============================================
  // HEADER
  // ============================================

  Widget _buildPremiumHeader(BuildContext context, User? currentUser) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A), Color(0xFF0F172A)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 40,
            offset: const Offset(0, 12),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Avatar with Premium Ring
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  child:
                      currentUser?.avatarUrl != null &&
                          currentUser!.avatarUrl!.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            currentUser.avatarUrl!,
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildAvatarText(currentUser);
                            },
                          ),
                        )
                      : _buildAvatarText(currentUser),
                ),
              ),
              const Spacer(),
              // Close button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // User Name
          Text(
            currentUser?.name ?? 'Admin',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // User Email
          Text(
            currentUser?.email ?? 'admin@quickfix.com',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Role Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF34D399),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currentUser?.isSuperAdmin == true
                          ? 'Super Admin'
                          : currentUser?.isAdmin == true
                          ? 'Administrator'
                          : currentUser?.isManager == true
                          ? 'Manager'
                          : 'Technician',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarText(User? currentUser) {
    return Text(
      Helpers.getInitials(currentUser?.name ?? 'Admin'),
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 26,
        shadows: [Shadow(blurRadius: 12, color: Colors.black26)],
      ),
    );
  }

  // ============================================
  // SECTION HEADER
  // ============================================

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textLight,
              letterSpacing: 1.8,
            ),
          ),
          const Spacer(),
          Container(width: 20, height: 1, color: AppColors.border),
        ],
      ),
    );
  }

  // ============================================
  // NAVIGATION ITEM
  // ============================================

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String title,
    required int index,
    required bool isSelected,
    required VoidCallback onTap,
    bool isLogout = false,
    String? badge,
  }) {
    final baseColor = isLogout ? AppColors.error : AppColors.primary;
    final iconColor = isSelected
        ? baseColor
        : isLogout
        ? AppColors.error
        : AppColors.textLight;
    final textColor = isSelected
        ? baseColor
        : isLogout
        ? AppColors.error
        : AppColors.text;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  baseColor.withValues(alpha: 0.12),
                  baseColor.withValues(alpha: 0.04),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: baseColor.withValues(alpha: 0.2), width: 1.5)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          splashColor: baseColor.withValues(alpha: 0.1),
          highlightColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Icon
                Icon(
                  isSelected ? activeIcon : icon,
                  color: iconColor,
                  size: 22,
                ),
                const SizedBox(width: 14),

                // Title
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Badge
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                // Selected Indicator
                Container(
                  width: isSelected ? 4 : 0,
                  height: 24,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: baseColor.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // DIVIDER
  // ============================================

  Widget _buildDivider() {
    return Container(height: 1, color: AppColors.border.withValues(alpha: 0.4));
  }

  // ============================================
  // FOOTER
  // ============================================

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Status Dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF34D399),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF34D399).withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Quickfix Plumbers',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textLight,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 12, color: AppColors.border),
          const SizedBox(width: 8),
          Text(
            'v1.0',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textLight,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  void _handleItemTap(BuildContext context, int index) {
    if (onItemSelected != null) {
      onItemSelected!(index);
    } else {
      _defaultOnItemSelected(context, index);
    }
  }

  void _defaultOnItemSelected(BuildContext context, int index) async {
    if (index == 9) {
      final authProvider = context.read<AuthProvider>();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Logout'),
            ),
          ],
        ),
      );

      if (confirm == true && context.mounted) {
        // Close drawer first
        Navigator.pop(context);
        await authProvider.logout();
        if (!context.mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      }
      return;
    }

    // Close drawer for standard menu items
    Navigator.pop(context);
    if (!context.mounted) return;

    final currentRoute = ModalRoute.of(context)?.settings.name;
    String? targetRoute;

    switch (index) {
      case 0:
        final authProvider = context.read<AuthProvider>();
        targetRoute = authProvider.isAdmin
            ? AppRoutes.adminDashboard
            : AppRoutes.technicianDashboard;
        break;
      case 1:
        targetRoute = AppRoutes.quotes;
        break;
      case 2:
        targetRoute = AppRoutes.customers;
        break;
      case 3:
        targetRoute = AppRoutes.products;
        break;
      case 4:
        targetRoute = AppRoutes.invoices;
        break;
      case 5:
        targetRoute = AppRoutes.createSiteQuote;
        break;
      case 6:
        targetRoute = AppRoutes.siteMeasurements;
        break;
      case 7:
        targetRoute = AppRoutes.myQuotes;
        break;
      case 8:
        targetRoute = AppRoutes.settings;
        break;
      case 10:
        targetRoute = AppRoutes.priceList;
        break;
      case 11:
        targetRoute = AppRoutes.reports;
        break;
      case 12:
        targetRoute = AppRoutes.systemLogs;
        break;
      case 13:
        targetRoute = AppRoutes.approvalRequests;
        break;
    }

    if (targetRoute != null && targetRoute != currentRoute) {
      if (index == 8) {
        Navigator.pushNamed(context, targetRoute);
      } else {
        Navigator.pushReplacementNamed(context, targetRoute);
      }
    }
  }
}
