import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/quote_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../widgets/sidebar_menu.dart';
import '../../utils/helpers.dart';
import '../../widgets/loading_spinner.dart';
import '../../widgets/sync_refresh_button.dart';

// ============================================
// ENUM DEFINED AT TOP LEVEL
// ============================================

enum Trend { up, down, neutral }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final quoteProvider = context.read<QuoteProvider>();
    final productProvider = context.read<ProductProvider>();
    final customerProvider = context.read<CustomerProvider>();
    final invoiceProvider = context.read<InvoiceProvider>();

    await Future.wait([
      quoteProvider.loadQuotes(),
      productProvider.loadProducts(),
      customerProvider.loadCustomers(),
      invoiceProvider.loadInvoices(),
    ]);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }

  String _formatCurrency(double amount) {
    return 'KSh ${amount.toStringAsFixed(2)}';
  }

  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 🌅';
    if (hour < 17) return 'Good Afternoon ☀️';
    return 'Good Evening 🌙';
  }

  Trend _getTrend(int value, int total) {
    if (total == 0) return Trend.neutral;
    if (value > total * 0.5) return Trend.up;
    if (value > total * 0.2) return Trend.neutral;
    return Trend.down;
  }



  // ============================================
  // BUILD METHOD
  // ============================================

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final quoteProvider = context.watch<QuoteProvider>();
    final productProvider = context.watch<ProductProvider>();
    final customerProvider = context.watch<CustomerProvider>();
    final invoiceProvider = context.watch<InvoiceProvider>();

    final quotes = quoteProvider.quotes;
    final products = productProvider.products;
    final customers = customerProvider.customers;
    final invoices = invoiceProvider.invoices;

    final totalQuotes = quotes.length;
    final pendingQuotes = quotes.where((q) => q.isDraft || q.isSent).length;
    final approvedQuotes = quotes.where((q) => q.isApproved).length;
    final lowStockCount = products.where((p) => p.isLowStock).length;
    final totalCustomers = customers.length;
    final totalValue = quotes.fold(0.0, (sum, q) => sum + q.total);
    final totalInvoices = invoices.length;
    final paidInvoices = invoices.where((i) => i.isPaid).length;
    final overdueInvoices = invoices.where((i) => i.isOverdue).length;

    final recentQuotes = quotes.take(5).toList();
    final recentInvoices = invoices.take(5).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(authProvider),
      drawer: const SidebarMenu(
        selectedIndex: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(
                child: LoadingSpinner(message: 'Loading dashboard...'),
              )
            : FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeSection(authProvider),
                      const SizedBox(height: 24),
                      _buildStatsRow(
                        totalQuotes,
                        pendingQuotes,
                        approvedQuotes,
                        lowStockCount,
                        totalCustomers,
                        totalValue,
                        totalInvoices,
                        paidInvoices,
                        overdueInvoices,
                      ),
                      const SizedBox(height: 24),
                      _buildQuickActions(),
                      const SizedBox(height: 24),
                      _buildSectionHeader('Recent Activity', Icons.history),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 900;
                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: _buildRecentQuotesTable(
                                    context,
                                    recentQuotes,
                                    quoteProvider,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 1,
                                  child: _buildRecentInvoicesTable(
                                    context,
                                    recentInvoices,
                                    invoiceProvider,
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildRecentQuotesTable(
                                  context,
                                  recentQuotes,
                                  quoteProvider,
                                ),
                                const SizedBox(height: 24),
                                _buildRecentInvoicesTable(
                                  context,
                                  recentInvoices,
                                  invoiceProvider,
                                ),
                              ],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  void _handleLogout(BuildContext context, AuthProvider authProvider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
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
    if (confirm == true) {
      await authProvider.logout();
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  // ============================================
  // APP BAR
  // ============================================

  PreferredSizeWidget _buildAppBar(AuthProvider authProvider) {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.dashboard, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Text(
            'Dashboard',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      elevation: 0,
      actions: [
        const SyncRefreshButton(color: Colors.white),
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  Helpers.showSnackBar(
                    context,
                    'No new notifications',
                    backgroundColor: AppColors.info,
                  );
                },
              ),
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => _handleLogout(context, authProvider),
        ),
      ],
    );
  }

  // ============================================
  // SECTION HEADER
  // ============================================

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            DateFormat('MMM d, yyyy').format(DateTime.now()),
            style: TextStyle(fontSize: 11, color: AppColors.textLight),
          ),
        ),
      ],
    );
  }

  // ============================================
  // WELCOME SECTION
  // ============================================

  Widget _buildWelcomeSection(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              child: Text(
                Helpers.getInitials(authProvider.currentUser?.name ?? 'Admin'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTimeOfDay(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  authProvider.currentUser?.name ?? 'Admin',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  authProvider.currentUser?.isSuperAdmin == true
                      ? Icons.security
                      : authProvider.isAdmin
                          ? Icons.admin_panel_settings
                          : Icons.engineering,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  authProvider.currentUser?.isSuperAdmin == true
                      ? 'Super Admin'
                      : authProvider.isAdmin
                          ? 'Admin'
                          : 'Technician',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // ============================================
  // STATS ROW
  // ============================================

  Widget _buildStatsRow(
    int totalQuotes,
    int pendingQuotes,
    int approvedQuotes,
    int lowStockCount,
    int totalCustomers,
    double totalValue,
    int totalInvoices,
    int paidInvoices,
    int overdueInvoices,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        double childAspectRatio = 1.6;
        if (constraints.maxWidth > 1100) {
          crossAxisCount = 6;
          childAspectRatio = 1.2;
        } else if (constraints.maxWidth > 700) {
          crossAxisCount = 3;
          childAspectRatio = 1.7;
        }

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
          children: [
            _buildStatCard(
              title: 'Total Quotes',
              value: totalQuotes.toString(),
              icon: Icons.receipt_long,
              color: AppColors.primary,
              detail: '$pendingQuotes pending',
              trend: _getTrend(totalQuotes, 0),
            ),
            _buildStatCard(
              title: 'Approved',
              value: approvedQuotes.toString(),
              icon: Icons.check_circle,
              color: AppColors.success,
              detail:
                  '${totalQuotes > 0 ? (approvedQuotes / totalQuotes * 100).toInt() : 0}% rate',
              trend: _getTrend(approvedQuotes, totalQuotes),
            ),
            _buildStatCard(
              title: 'Invoices',
              value: totalInvoices.toString(),
              icon: Icons.receipt,
              color: AppColors.secondary,
              detail: '$paidInvoices paid',
              trend: _getTrend(totalInvoices, 0),
            ),
            _buildStatCard(
              title: 'Overdue',
              value: overdueInvoices.toString(),
              icon: Icons.warning,
              color: AppColors.error,
              detail: overdueInvoices > 0 ? '⚠️ Action needed' : '✓ All good',
              trend: overdueInvoices > 0 ? Trend.down : Trend.up,
            ),
            _buildStatCard(
              title: 'Customers',
              value: totalCustomers.toString(),
              icon: Icons.people,
              color: AppColors.info,
              detail: 'Active accounts',
              trend: _getTrend(totalCustomers, 0),
            ),
            _buildStatCard(
              title: 'Low Stock',
              value: lowStockCount.toString(),
              icon: Icons.inventory,
              color: lowStockCount > 0 ? AppColors.warning : AppColors.success,
              detail: lowStockCount > 0 ? '⚠️ Reorder soon' : '✓ Stock ok',
              trend: lowStockCount > 0 ? Trend.down : Trend.up,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? detail,
    Trend? trend,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              if (trend != null && trend != Trend.neutral)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (trend == Trend.up ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    trend == Trend.up ? Icons.trending_up : Icons.trending_down,
                    size: 12,
                    color: trend == Trend.up ? AppColors.success : AppColors.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 1),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.textLight.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ============================================
  // QUICK ACTIONS
  // ============================================

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Quick Actions', Icons.flash_on),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickAction(
                icon: Icons.add_circle_outline,
                label: 'New Quote',
                color: AppColors.primary,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.createQuote),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickAction(
                icon: Icons.person_add_outlined,
                label: 'Add Customer',
                color: AppColors.info,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.addCustomer),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickAction(
                icon: Icons.inventory_2_outlined,
                label: 'Add Product',
                color: AppColors.secondary,
                onTap: () => Navigator.pushNamed(context, AppRoutes.addProduct),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // RECENT QUOTES TABLE
  // ============================================

  Widget _buildRecentQuotesTable(
    BuildContext context,
    List quotes,
    QuoteProvider quoteProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Recent Quotes',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.quotes),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(60, 36),
              ),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (quoteProvider.isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (quotes.isEmpty)
          _buildEmptyState(Icons.receipt_long_outlined, 'No quotes yet')
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktopTable = constraints.maxWidth > 600;
              if (isDesktopTable) {
                return _buildRecentQuotesDesktopTable(context, quotes);
              } else {
                return _buildRecentQuotesMobileList(context, quotes);
              }
            },
          ),
      ],
    );
  }

  Widget _buildRecentQuotesMobileList(BuildContext context, List quotes) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: quotes.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: AppColors.border.withValues(alpha: 0.3),
        ),
        itemBuilder: (context, index) {
          final quote = quotes[index];
          final statusColor = Helpers.getStatusColor(quote.status);
          final statusBgColor = AppColors.getStatusBackgroundColor(quote.status);

          return ListTile(
            onTap: () => Navigator.pushNamed(
              context,
              '${AppRoutes.quoteDetails}/${quote.id}',
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  quote.quoteNumber,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  _formatCurrency(quote.total),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${quote.customerName ?? 'Unknown'} • ${_formatDate(quote.createdAt)}',
                      style: TextStyle(fontSize: 12, color: AppColors.textLight),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      quote.displayStatus,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentQuotesDesktopTable(BuildContext context, List quotes) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: _buildHeaderCell('#', center: true),
                ),
                Expanded(flex: 3, child: _buildHeaderCell('Quote #')),
                Expanded(flex: 4, child: _buildHeaderCell('Customer')),
                Expanded(
                  flex: 2,
                  child: _buildHeaderCell('Date', center: true),
                ),
                Expanded(
                  flex: 3,
                  child: _buildHeaderCell('Amount', center: true),
                ),
                Expanded(
                  flex: 3,
                  child: _buildHeaderCell('Status', center: true),
                ),
              ],
            ),
          ),
          // Table Body
          ...List.generate(quotes.length, (index) {
            final quote = quotes[index];
            final statusColor = Helpers.getStatusColor(quote.status);
            final statusBgColor = AppColors.getStatusBackgroundColor(
              quote.status,
            );
            final isDraft = quote.isDraft;

            return InkWell(
              onTap: () => Navigator.pushNamed(
                context,
                '${AppRoutes.quoteDetails}/${quote.id}',
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDraft
                      ? AppColors.draftBackground
                      : index.isEven
                      ? Colors.white
                      : AppColors.background,
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildCell(
                        '${index + 1}',
                        center: true,
                        color: AppColors.textLight,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: _buildCell(quote.quoteNumber, isBold: true),
                    ),
                    Expanded(
                      flex: 4,
                      child: _buildCell(quote.customerName ?? 'Unknown'),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildCell(
                        _formatDate(quote.createdAt),
                        center: true,
                        color: AppColors.textLight,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: _buildCell(
                        _formatCurrency(quote.total),
                        center: true,
                        isBold: true,
                        color: AppColors.primary,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Helpers.getStatusIcon(quote.status),
                                size: 10,
                                color: statusColor,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                quote.displayStatus,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${quotes.length} recent quotes',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textLight,
                  ),
                ),
                Text(
                  'Total: ${_formatCurrency(quotes.fold(0.0, (sum, q) => sum + q.total))}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // RECENT INVOICES TABLE
  // ============================================

  Widget _buildRecentInvoicesTable(
    BuildContext context,
    List invoices,
    InvoiceProvider invoiceProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.receipt,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Recent Invoices',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.invoices),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(60, 36),
              ),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (invoiceProvider.isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (invoices.isEmpty)
          _buildEmptyState(Icons.receipt_outlined, 'No invoices yet')
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktopTable = constraints.maxWidth > 600;
              if (isDesktopTable) {
                return _buildRecentInvoicesDesktopTable(context, invoices);
              } else {
                return _buildRecentInvoicesMobileList(context, invoices);
              }
            },
          ),
      ],
    );
  }

  Widget _buildRecentInvoicesMobileList(BuildContext context, List invoices) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: invoices.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: AppColors.border.withValues(alpha: 0.3),
        ),
        itemBuilder: (context, index) {
          final invoice = invoices[index];
          final statusColor = invoice.isPaid
              ? AppColors.success
              : invoice.isOverdue
                  ? AppColors.error
                  : AppColors.warning;
          final statusBgColor = invoice.isPaid
              ? AppColors.successBackground
              : invoice.isOverdue
                  ? AppColors.errorBackground
                  : AppColors.warningBackground;
          final statusText = invoice.isPaid
              ? 'Paid'
              : invoice.isOverdue
                  ? 'Overdue'
                  : 'Unpaid';

          return ListTile(
            onTap: () => Navigator.pushNamed(
              context,
              '${AppRoutes.invoiceDetails}/${invoice.id}',
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  invoice.invoiceNumber,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  _formatCurrency(invoice.total),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${invoice.customerName ?? 'Unknown'} • ${_formatDate(invoice.createdAt)}',
                      style: TextStyle(fontSize: 12, color: AppColors.textLight),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentInvoicesDesktopTable(BuildContext context, List invoices) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: _buildHeaderCell('#', center: true),
                ),
                Expanded(flex: 3, child: _buildHeaderCell('Invoice #')),
                Expanded(flex: 4, child: _buildHeaderCell('Customer')),
                Expanded(
                  flex: 2,
                  child: _buildHeaderCell('Date', center: true),
                ),
                Expanded(
                  flex: 3,
                  child: _buildHeaderCell('Amount', center: true),
                ),
                Expanded(
                  flex: 3,
                  child: _buildHeaderCell('Status', center: true),
                ),
              ],
            ),
          ),
          // Table Body
          ...List.generate(invoices.length, (index) {
            final invoice = invoices[index];
            final statusColor = invoice.isPaid
                ? AppColors.success
                : invoice.isOverdue
                ? AppColors.error
                : AppColors.warning;
            final statusBgColor = invoice.isPaid
                ? AppColors.successBackground
                : invoice.isOverdue
                ? AppColors.errorBackground
                : AppColors.warningBackground;
            final statusText = invoice.isPaid
                ? 'Paid'
                : invoice.isOverdue
                ? 'Overdue'
                : 'Unpaid';

            return InkWell(
              onTap: () => Navigator.pushNamed(
                context,
                '${AppRoutes.invoiceDetails}/${invoice.id}',
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: invoice.isOverdue
                      ? AppColors.errorBackground
                      : index.isEven
                      ? Colors.white
                      : AppColors.background,
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildCell(
                        '${index + 1}',
                        center: true,
                        color: AppColors.textLight,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: _buildCell(
                        invoice.invoiceNumber,
                        isBold: true,
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: _buildCell(
                        invoice.customerName ?? 'Unknown',
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildCell(
                        _formatDate(invoice.createdAt),
                        center: true,
                        color: AppColors.textLight,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: _buildCell(
                        _formatCurrency(invoice.total),
                        center: true,
                        isBold: true,
                        color: AppColors.primary,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                invoice.isPaid
                                    ? Icons.check_circle
                                    : invoice.isOverdue
                                    ? Icons.warning
                                    : Icons.pending,
                                size: 10,
                                color: statusColor,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${invoices.length} recent invoices',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textLight,
                  ),
                ),
                Text(
                  'Total: ${_formatCurrency(invoices.fold(0.0, (sum, i) => sum + i.total))}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // TABLE HELPERS
  // ============================================

  Widget _buildHeaderCell(String text, {bool center = false}) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
      textAlign: center ? TextAlign.center : TextAlign.left,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildCell(
    String text, {
    bool isBold = false,
    Color? color,
    bool center = false,
  }) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
        color: color ?? AppColors.text,
      ),
      textAlign: center ? TextAlign.center : TextAlign.left,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  // ============================================
  // EMPTY STATE
  // ============================================

  Widget _buildEmptyState(IconData icon, String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: AppColors.textLight),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
