import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/quote_provider.dart';
import '../../models/quote.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/sidebar_menu.dart';
import '../../utils/helpers.dart';
import '../../widgets/sync_refresh_button.dart';

class MyQuotes extends StatefulWidget {
  const MyQuotes({super.key});

  @override
  State<MyQuotes> createState() => _MyQuotesState();
}

class _MyQuotesState extends State<MyQuotes>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _selectedStatus = 'All';
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _statusOptions = [
    'All',
    Constants.quoteStatusDraft,
    Constants.quoteStatusSent,
    Constants.quoteStatusApproved,
    Constants.quoteStatusConverted,
    Constants.quoteStatusRejected,
  ];

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
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadQuotes();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadQuotes() async {
    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final quoteProvider = context.read<QuoteProvider>();
    quoteProvider.clearAllFilters();

    final userId = authProvider.currentUser?.id;
    if (userId != null) {
      await quoteProvider.loadQuotesByUser(userId);
    }

    setState(() => _isLoading = false);
  }

  void _filterQuotes() {
    setState(() {});
  }

  List<Quote> _getFilteredQuotes(QuoteProvider provider) {
    final query = _searchController.text.toLowerCase().trim();
    var list = provider.allQuotes;

    if (query.isNotEmpty) {
      list = list.where((q) {
        return q.quoteNumber.toLowerCase().contains(query) ||
            (q.customerName?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    if (_selectedStatus != 'All') {
      list = list.where((q) => q.status == _selectedStatus).toList();
    }

    return list;
  }

  String _getStatusDisplayName(String status) {
    if (status == 'All') return 'All';
    return Constants.quoteStatusDisplay[status] ?? status;
  }

  Color _getStatusColor(String status) {
    if (status == 'All') return AppColors.text;
    return AppColors.getStatusColor(status);
  }

  Color _getStatusBackgroundColor(String status) {
    if (status == 'All') return AppColors.background;
    return AppColors.getStatusBackgroundColor(status);
  }

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuoteProvider>();
    final displayedQuotes = _getFilteredQuotes(provider);

    // Calculate stats
    final draftCount = displayedQuotes.where((q) => q.isDraft).length;
    final sentCount = displayedQuotes.where((q) => q.isSent).length;
    final approvedCount = displayedQuotes.where((q) => q.isApproved).length;
    final convertedCount = displayedQuotes.where((q) => q.isConverted).length;
    final rejectedCount = displayedQuotes.where((q) => q.isRejected).length;
    final totalAmount = displayedQuotes.fold(
      0.0,
      (sum, q) => sum + q.grandTotal,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Quotes',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/technician/quotes/create');
            },
            tooltip: 'New Quote',
          ),
          const SyncRefreshButton(color: Colors.white),
        ],
      ),
      drawer: const SidebarMenu(
        selectedIndex: 7,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildSearchAndFilterBar(),
            _buildStatsBar(
              total: displayedQuotes.length,
              draftCount: draftCount,
              sentCount: sentCount,
              approvedCount: approvedCount,
              convertedCount: convertedCount,
              rejectedCount: rejectedCount,
              totalAmount: totalAmount,
            ),
            Expanded(
              child: _isLoading || provider.isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Loading your quotes...',
                            style: TextStyle(color: AppColors.textLight),
                          ),
                        ],
                      ),
                    )
                  : displayedQuotes.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadQuotes,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _buildQuoteTable(displayedQuotes),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // SEARCH AND FILTER BAR
  // ============================================

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => _filterQuotes(),
                  decoration: InputDecoration(
                    hintText: 'Search my quotes...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textLight,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: AppColors.textLight,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _filterQuotes();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _filterQuotes(),
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'Search',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _statusOptions.length,
              itemBuilder: (context, index) {
                final status = _statusOptions[index];
                final isSelected = status == _selectedStatus;
                final statusColor = _getStatusColor(status);
                _getStatusBackgroundColor(status);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedStatus = status;
                    });
                    _filterQuotes();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? statusColor : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? statusColor : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected) ...[
                          const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          _getStatusDisplayName(status),
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.text,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // STATS BAR
  // ============================================

  Widget _buildStatsBar({
    required int total,
    required int draftCount,
    required int sentCount,
    required int approvedCount,
    required int convertedCount,
    required int rejectedCount,
    required double totalAmount,
  }) {
    final hasFilters =
        _selectedStatus != 'All' || _searchController.text.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$total',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'quotes',
                style: TextStyle(fontSize: 13, color: AppColors.textLight),
              ),
              const SizedBox(width: 12),
              if (draftCount > 0)
                _buildStatChip(
                  '$draftCount draft',
                  AppColors.draft,
                  AppColors.draftBackground,
                ),
              if (sentCount > 0)
                _buildStatChip(
                  '$sentCount sent',
                  AppColors.sent,
                  AppColors.sentBackground,
                ),
              if (approvedCount > 0)
                _buildStatChip(
                  '$approvedCount approved',
                  AppColors.approved,
                  AppColors.approvedBackground,
                ),
              if (convertedCount > 0)
                _buildStatChip(
                  '$convertedCount converted',
                  AppColors.converted,
                  AppColors.convertedBackground,
                ),
              if (rejectedCount > 0)
                _buildStatChip(
                  '$rejectedCount rejected',
                  AppColors.rejected,
                  AppColors.rejectedBackground,
                ),
            ],
          ),
          Row(
            children: [
              Text(
                'Total: ',
                style: TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
              Text(
                _formatCurrency(totalAmount),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              if (hasFilters) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedStatus = 'All';
                      _searchController.clear();
                    });
                    _filterQuotes();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.clear,
                          size: 14,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ============================================
  // QUOTE TABLE (FULL WIDTH)
  // ============================================

  Widget _buildQuoteTable(List<Quote> displayedQuotes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(flex: 1, child: _buildHeaderCell('#', center: true)),
              Expanded(flex: 2, child: _buildHeaderCell('Quote #')),
              Expanded(flex: 3, child: _buildHeaderCell('Customer')),
              Expanded(flex: 2, child: _buildHeaderCell('Date', center: true)),
              Expanded(
                flex: 2,
                child: _buildHeaderCell('Amount', center: true),
              ),
              Expanded(
                flex: 2,
                child: _buildHeaderCell('Status', center: true),
              ),
              Expanded(
                flex: 2,
                child: _buildHeaderCell('Actions', center: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Table Body
        ...displayedQuotes.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final quote = entry.value;
          final statusColor = AppColors.getStatusColor(quote.status);
          final statusBgColor = AppColors.getStatusBackgroundColor(
            quote.status,
          );
          final isDraft = quote.isDraft;

          return InkWell(
            onTap: () {
              Navigator.pushNamed(context, '/admin/quotes/${quote.id}');
            },
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDraft
                    ? AppColors.draftBackground
                    : index.isEven
                    ? Colors.white
                    : AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: isDraft
                    ? Border.all(color: AppColors.draft, width: 1)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // # (Index)
                  Expanded(
                    flex: 1,
                    child: _buildCell(
                      index.toString(),
                      center: true,
                      color: AppColors.textLight,
                    ),
                  ),
                  // Quote Number
                  Expanded(
                    flex: 2,
                    child: _buildCell(quote.quoteNumber, isBold: true),
                  ),
                  // Customer
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.1,
                          ),
                          child: Text(
                            Helpers.getInitials(quote.customerName ?? 'U'),
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            quote.customerName ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Date
                  Expanded(
                    flex: 2,
                    child: _buildCell(
                      _formatDate(quote.createdAt),
                      center: true,
                      color: AppColors.textLight,
                    ),
                  ),
                  // Amount
                  Expanded(
                    flex: 2,
                    child: _buildCell(
                      _formatCurrency(quote.grandTotal),
                      center: true,
                      isBold: true,
                      color: AppColors.primary,
                    ),
                  ),
                  // Status
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Helpers.getStatusIcon(quote.status),
                              size: 12,
                              color: statusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              quote.displayStatus,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Actions
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.visibility,
                            size: 18,
                            color: AppColors.info,
                          ),
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/admin/quotes/${quote.id}',
                            );
                          },
                          tooltip: 'View',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        if (quote.isEditable)
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/admin/quotes/edit/${quote.id}',
                              );
                            },
                            tooltip: 'Edit',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        if (quote.canConvertToInvoice)
                          IconButton(
                            icon: const Icon(
                              Icons.receipt,
                              size: 18,
                              color: AppColors.secondary,
                            ),
                            onPressed: () {
                              _showConvertDialog(quote);
                            },
                            tooltip: 'Convert to Invoice',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        // Footer
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${displayedQuotes.length} quotes',
                style: TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
              Text(
                'Total: ${_formatCurrency(displayedQuotes.fold(0.0, (sum, q) => sum + q.grandTotal))}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String text, {bool center = false}) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 12,
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
        fontSize: 13,
        fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
        color: color ?? AppColors.text,
      ),
      textAlign: center ? TextAlign.center : TextAlign.left,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  // ============================================
  // CONVERT DIALOG
  // ============================================

  Future<void> _showConvertDialog(Quote quote) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convert to Invoice'),
        content: Text(
          'Are you sure you want to convert quote "${quote.quoteNumber}" to an invoice?',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Convert'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    final provider = context.read<QuoteProvider>();
    final invoice = await provider.convertQuoteToInvoice(quote.id);

    if (!mounted) return;

    if (invoice != null) {
      Helpers.showSuccess(context, 'Quote converted to invoice successfully');
      await _loadQuotes();
      if (!mounted) return;
      Navigator.pushNamed(context, '/admin/invoices/${invoice.id}');
    } else {
      Helpers.showError(
        context,
        provider.errorMessage ?? 'Failed to convert quote to invoice',
      );
    }
  }

  // ============================================
  // EMPTY STATE
  // ============================================

  Widget _buildEmptyState() {
    final hasFilters =
        _searchController.text.isNotEmpty || _selectedStatus != 'All';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasFilters ? Icons.search_off : Icons.receipt_long_outlined,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'No matching quotes' : 'No quotes yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? 'Try adjusting your search or filters'
                : 'Create your first site quote to get started',
            style: TextStyle(fontSize: 14, color: AppColors.textLight),
          ),
          const SizedBox(height: 24),
          if (!hasFilters)
            CustomButton(
              text: 'Create Site Quote',
              onPressed: () {
                Navigator.pushNamed(context, '/technician/quotes/create');
              },
              icon: Icons.add_location_alt,
              variant: ButtonVariant.primary,
              size: ButtonSize.medium,
            ),
          if (hasFilters)
            CustomButton(
              text: 'Clear Filters',
              onPressed: () {
                setState(() {
                  _selectedStatus = 'All';
                  _searchController.clear();
                });
                _filterQuotes();
              },
              icon: Icons.clear_all,
              variant: ButtonVariant.primary,
              size: ButtonSize.medium,
            ),
        ],
      ),
    );
  }
}
