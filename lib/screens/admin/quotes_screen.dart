import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../providers/quote_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/quote.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/sidebar_menu.dart';
import '../../utils/helpers.dart';
import '../../widgets/sync_refresh_button.dart';

class QuotesScreen extends StatefulWidget {
  const QuotesScreen({super.key});

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _selectedStatus = 'All';
  final Set<String> _expandedQuotes = {};
  bool _isLoading = false;
  final Map<String, List<dynamic>> _quoteItemsCache = {};
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
    final provider = context.read<QuoteProvider>();
    provider.clearAllFilters();
    await provider.loadQuotes(forceRefresh: true);
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
    return Helpers.getStatusColor(status);
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

  Future<void> _toggleExpanded(String quoteId) async {
    // If expanding, fetch items if not cached
    if (!_expandedQuotes.contains(quoteId)) {
      // Check if we already have items cached
      if (!_quoteItemsCache.containsKey(quoteId)) {
        setState(() => _isLoading = true);
        try {
          final provider = context.read<QuoteProvider>();
          // Use the provider's getQuote method which fetches items
          final quote = await provider.getQuote(quoteId);
          if (quote != null && quote.items != null && quote.items!.isNotEmpty) {
            setState(() {
              // Cache the items
              _quoteItemsCache[quoteId] = quote.items!;
            });
          } else {
            // Try fetching items directly
            final items = await provider.getQuoteItems(quoteId);
            setState(() {
              _quoteItemsCache[quoteId] = items;
            });
          }
        } catch (e) {
          setState(() {
            _quoteItemsCache[quoteId] = [];
          });
          if (kDebugMode) {
            print('Error fetching quote items: $e');
          }
        }
        setState(() => _isLoading = false);
      }
    }

    setState(() {
      if (_expandedQuotes.contains(quoteId)) {
        _expandedQuotes.remove(quoteId);
      } else {
        _expandedQuotes.add(quoteId);
      }
    });
  }

  // ============================================
  // QUOTE ACTIONS
  // ============================================

  void _viewQuote(Quote quote) {
    Navigator.pushNamed(context, '/admin/quotes/${quote.id}');
  }

  void _editQuote(Quote quote) {
    if (!quote.isEditable) {
      Helpers.showSnackBar(
        context,
        'This quote cannot be edited',
        backgroundColor: AppColors.warning,
      );
      return;
    }
    Navigator.pushNamed(context, '/admin/quotes/edit/${quote.id}');
  }

  Future<void> _convertToInvoice(Quote quote) async {
    if (!quote.canConvertToInvoice) {
      Helpers.showSnackBar(
        context,
        'This quote cannot be converted to invoice',
        backgroundColor: AppColors.warning,
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convert to Invoice'),
        content: Text(
          'Are you sure you want to convert quote "${quote.quoteNumber}" to an invoice?',
        ),
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
    final quoteId = quote.id;
    final provider = context.read<QuoteProvider>();
    final invoice = await provider.convertQuoteToInvoice(quoteId);

    if (!mounted) return;

    if (invoice != null) {
      if (mounted) {
        context.read<InvoiceProvider>().loadInvoices(forceRefresh: true);
      }
      Helpers.showSuccess(context, 'Quote converted to invoice successfully');
      await _loadQuotes();
      if (mounted) {
        Navigator.pushNamed(context, '/admin/invoices/${invoice.id}');
      }
    } else {
      Helpers.showError(
        context,
        provider.errorMessage ?? 'Failed to convert quote to invoice',
      );
    }
  }

  Future<void> _deleteQuote(Quote quote) async {
    if (quote.isConverted) {
      Helpers.showSnackBar(
        context,
        'Converted quotes cannot be deleted',
        backgroundColor: AppColors.warning,
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quote'),
        content: Text(
          'Are you sure you want to delete quote "${quote.quoteNumber}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    final quoteId = quote.id;
    final provider = context.read<QuoteProvider>();
    final success = await provider.deleteQuote(quoteId);

    if (!mounted) return;

    if (success) {
      Helpers.showSuccess(context, 'Quote deleted successfully');
      await _loadQuotes();
    } else {
      Helpers.showError(
        context,
        provider.errorMessage ?? 'Failed to delete quote',
      );
    }
  }

  Future<void> _duplicateQuote(Quote quote) async {
    Helpers.showSnackBar(
      context,
      'Duplicate quote feature coming soon',
      backgroundColor: AppColors.info,
    );
  }

  Future<void> _emailQuote(Quote quote) async {
    Helpers.showSnackBar(
      context,
      'Email quote feature coming soon',
      backgroundColor: AppColors.info,
    );
  }

  Future<void> _printQuote(Quote quote) async {
    Helpers.showSnackBar(
      context,
      'Print quote feature coming soon',
      backgroundColor: AppColors.info,
    );
  }

  void _showMoreActions(Quote quote) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Quote Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Quote #${quote.quoteNumber}',
              style: TextStyle(fontSize: 14, color: AppColors.textLight),
            ),
            const SizedBox(height: 16),
            _buildActionTile(
              icon: Icons.visibility,
              title: 'View Quote',
              subtitle: 'View quote details',
              color: AppColors.info,
              onTap: () {
                Navigator.pop(context);
                _viewQuote(quote);
              },
            ),
            _buildActionTile(
              icon: Icons.edit,
              title: 'Edit Quote',
              subtitle: quote.isEditable
                  ? 'Modify quote details'
                  : 'Quote cannot be edited',
              color: AppColors.primary,
              onTap: quote.isEditable
                  ? () {
                      Navigator.pop(context);
                      _editQuote(quote);
                    }
                  : null,
            ),
            _buildActionTile(
              icon: Icons.receipt,
              title: 'Convert to Invoice',
              subtitle: quote.canConvertToInvoice
                  ? 'Create invoice from this quote'
                  : 'Quote cannot be converted',
              color: AppColors.secondary,
              onTap: quote.canConvertToInvoice
                  ? () {
                      Navigator.pop(context);
                      _convertToInvoice(quote);
                    }
                  : null,
            ),
            _buildActionTile(
              icon: Icons.content_copy,
              title: 'Duplicate Quote',
              subtitle: 'Create a copy of this quote',
              color: AppColors.info,
              onTap: () {
                Navigator.pop(context);
                _duplicateQuote(quote);
              },
            ),
            _buildActionTile(
              icon: Icons.email,
              title: 'Email Quote',
              subtitle: 'Send quote via email',
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                _emailQuote(quote);
              },
            ),
            _buildActionTile(
              icon: Icons.print,
              title: 'Print Quote',
              subtitle: 'Print quote document',
              color: AppColors.secondary,
              onTap: () {
                Navigator.pop(context);
                _printQuote(quote);
              },
            ),
            _buildActionTile(
              icon: Icons.delete_outline,
              title: 'Delete Quote',
              subtitle: quote.isConverted
                  ? 'Converted quotes cannot be deleted'
                  : 'Permanently delete this quote',
              color: AppColors.error,
              onTap: !quote.isConverted
                  ? () {
                      Navigator.pop(context);
                      _deleteQuote(quote);
                    }
                  : null,
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Close',
              onPressed: () => Navigator.pop(context),
              isOutlined: true,
              variant: ButtonVariant.outlined,
              size: ButtonSize.medium,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: onTap == null ? AppColors.textLight : AppColors.text,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: onTap == null
              ? AppColors.textLight.withValues(alpha: 0.5)
              : AppColors.textLight,
        ),
      ),
      trailing: onTap != null
          ? const Icon(Icons.chevron_right, color: AppColors.textLight)
          : null,
      onTap: onTap,
      enabled: onTap != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuoteProvider>();
    final authProvider = context.watch<AuthProvider>();
    final displayedQuotes = _getFilteredQuotes(provider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Quotations',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.createQuote);
            },
            tooltip: 'New Quote',
          ),
          const SyncRefreshButton(color: Colors.white),
        ],
      ),
      drawer: const SidebarMenu(
        selectedIndex: 1,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildSearchAndFilterBar(provider),
            _buildStatsBar(displayedQuotes),
            Expanded(
              child: _isLoading || provider.isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Loading quotes...',
                            style: TextStyle(color: AppColors.textLight),
                          ),
                        ],
                      ),
                    )
                  : displayedQuotes.isEmpty
                  ? _buildEmptyState()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final availableW = constraints.maxWidth - 32;
                        final tableW = availableW > 1100 ? availableW : 1100.0;
                        return RefreshIndicator(
                          onRefresh: _loadQuotes,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: tableW,
                                child: _buildQuoteTable(authProvider, displayedQuotes),
                              ),
                            ),
                          ),
                        );
                      },
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

  Widget _buildSearchAndFilterBar(QuoteProvider provider) {
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
                    hintText: 'Search quotes...',
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

                final statusQuotes = status == 'All'
                    ? provider.allQuotes
                    : provider.allQuotes.where((q) => q.status == status).toList();
                final statusCount = statusQuotes.length;
                final statusValue = statusQuotes.fold(0.0, (sum, q) => sum + q.effectiveTotal);

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
                      horizontal: 14,
                      vertical: 6,
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
                          '${_getStatusDisplayName(status)} ($statusCount • ${_formatCurrency(statusValue)})',
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.text,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
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

  Widget _buildStatsBar(List<Quote> displayedQuotes) {
    final total = displayedQuotes.length;
    final totalAmount = displayedQuotes.fold(0.0, (sum, q) => sum + q.effectiveTotal);

    final draftQuotes = displayedQuotes.where((q) => q.isDraft);
    final draftCount = draftQuotes.length;
    final draftValue = draftQuotes.fold(0.0, (sum, q) => sum + q.effectiveTotal);

    final sentQuotes = displayedQuotes.where((q) => q.isSent);
    final sentCount = sentQuotes.length;
    final sentValue = sentQuotes.fold(0.0, (sum, q) => sum + q.effectiveTotal);

    final approvedQuotes = displayedQuotes.where((q) => q.isApproved);
    final approvedCount = approvedQuotes.length;
    final approvedValue = approvedQuotes.fold(0.0, (sum, q) => sum + q.effectiveTotal);

    final convertedQuotes = displayedQuotes.where((q) => q.isConverted);
    final convertedCount = convertedQuotes.length;
    final convertedValue = convertedQuotes.fold(0.0, (sum, q) => sum + q.effectiveTotal);

    final rejectedQuotes = displayedQuotes.where((q) => q.isRejected);
    final rejectedCount = rejectedQuotes.length;
    final rejectedValue = rejectedQuotes.fold(0.0, (sum, q) => sum + q.effectiveTotal);

    final hasFilters =
        _selectedStatus != 'All' || _searchController.text.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
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
                      '$total (${_formatCurrency(totalAmount)})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'quotes found',
                    style: TextStyle(fontSize: 13, color: AppColors.textLight),
                  ),
                  const SizedBox(width: 12),
                  if (draftCount > 0)
                    _buildStatChip('$draftCount draft (${_formatCurrency(draftValue)})', AppColors.draft),
                  if (sentCount > 0)
                    _buildStatChip('$sentCount sent (${_formatCurrency(sentValue)})', AppColors.sent),
                  if (approvedCount > 0)
                    _buildStatChip('$approvedCount approved (${_formatCurrency(approvedValue)})', AppColors.approved),
                  if (convertedCount > 0)
                    _buildStatChip('$convertedCount converted (${_formatCurrency(convertedValue)})', AppColors.converted),
                  if (rejectedCount > 0)
                    _buildStatChip('$rejectedCount rejected (${_formatCurrency(rejectedValue)})', AppColors.rejected),
                ],
              ),
            ),
          ),
          if (hasFilters)
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
                    const Icon(Icons.clear, size: 14, color: AppColors.error),
                    const SizedBox(width: 4),
                    Text(
                      'Clear filters',
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
      ),
    );
  }

  Widget _buildStatChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
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
  // QUOTE TABLE (FULL WIDTH WITH EXPANDABLE ITEMS)
  // ============================================

  Widget _buildQuoteTable(AuthProvider authProvider, List<Quote> displayedQuotes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              const Expanded(
                flex: 1,
                child: Text(
                  ' #',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Expanded(
                flex: 3,
                child: Text(
                  'Quote #',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Expanded(
                flex: 3,
                child: Text(
                  'Customer',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Expanded(
                flex: 2,
                child: Text(
                  'Date',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Expanded(
                flex: 3,
                child: Text(
                  'Amount',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Expanded(
                flex: 3,
                child: Text(
                  'Status',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Expanded(
                flex: 4,
                child: Text(
                  'Actions',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Expanded(
                flex: 2,
                child: Text(
                  'Items',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Table Body
        ...displayedQuotes.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final quote = entry.value;
          final statusColor = Helpers.getStatusColor(quote.status);
          final isExpanded = _expandedQuotes.contains(quote.id);
          final itemCount = quote.items?.length ?? 0;

          return Column(
            children: [
              // Main Row
              InkWell(
                onTap: () => _viewQuote(quote),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: index.isEven ? Colors.white : AppColors.background,
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
                        child: Text(
                          index.toString(),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          quote.quoteNumber,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          quote.customerName ?? 'Unknown',
                          style: TextStyle(fontSize: 13, color: AppColors.text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _formatDate(quote.createdAt),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textLight,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          _formatCurrency(quote.effectiveTotal),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: _buildStatusCell(
                          quote.displayStatus,
                          statusColor,
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: _buildActionsCell(quote, statusColor),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildExpandCell(
                          quote.id,
                          isExpanded,
                          itemCount,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Expanded Items Row - Now uses the cached items
              if (isExpanded) _buildExpandedItems(quote),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildStatusCell(String status, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Helpers.getStatusIcon(status.toLowerCase()),
          size: 14,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionsCell(Quote quote, Color statusColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.visibility, size: 20, color: AppColors.info),
          onPressed: () => _viewQuote(quote),
          tooltip: 'View',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        IconButton(
          icon: Icon(
            Icons.edit,
            size: 20,
            color: quote.isEditable ? AppColors.primary : AppColors.textLight,
          ),
          onPressed: quote.isEditable ? () => _editQuote(quote) : null,
          tooltip: quote.isEditable ? 'Edit' : 'Cannot edit',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        IconButton(
          icon: Icon(
            Icons.receipt,
            size: 20,
            color: quote.canConvertToInvoice
                ? AppColors.secondary
                : AppColors.textLight,
          ),
          onPressed: quote.canConvertToInvoice
              ? () => _convertToInvoice(quote)
              : null,
          tooltip: quote.canConvertToInvoice
              ? 'Convert to Invoice'
              : 'Cannot convert',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        IconButton(
          icon: const Icon(
            Icons.more_vert,
            size: 20,
            color: AppColors.textLight,
          ),
          onPressed: () => _showMoreActions(quote),
          tooltip: 'More Actions',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildExpandCell(String quoteId, bool isExpanded, int itemCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$itemCount',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(
            isExpanded ? Icons.expand_less : Icons.expand_more,
            size: 20,
            color: AppColors.primary,
          ),
          onPressed: () => _toggleExpanded(quoteId),
          tooltip: isExpanded ? 'Hide items' : 'Show items',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildExpandedItems(Quote quote) {
    // Get items from cache or use quote.items
    List items = _quoteItemsCache[quote.id] ?? quote.items ?? [];

    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: AppColors.background,
        child: const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'No items in this quote',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textLight,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return _buildExpandedItemsDesktop(quote, items);
  }

  Widget _buildExpandedItemsDesktop(Quote quote, List items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppColors.background.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Quote Items',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          const Divider(),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const SizedBox(
                    width: 30,
                    child: Text(
                      '•',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.description,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (item.productName != null)
                          Text(
                            item.productName!,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textLight,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${item.quantity}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      _formatCurrency(item.unitPrice),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Text(
                      _formatCurrency(item.total),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'Subtotal: ',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  _formatCurrency(quote.subtotal),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Tax: ',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  _formatCurrency(quote.tax),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Total: ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  _formatCurrency(quote.grandTotal),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasFilters ? Icons.search_off : Icons.receipt_long_outlined,
              size: 48,
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
                : 'Create your first quotation',
            style: TextStyle(fontSize: 14, color: AppColors.textLight),
          ),
          if (!hasFilters) ...[
            const SizedBox(height: 24),
            CustomButton(
              text: 'Create Quote',
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.createQuote);
              },
              icon: Icons.add,
              variant: ButtonVariant.primary,
              size: ButtonSize.medium,
            ),
          ],
        ],
      ),
    );
  }
}
