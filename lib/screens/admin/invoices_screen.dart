import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/constants.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/customer_provider.dart';
import '../../models/invoice.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/sidebar_menu.dart';
import '../../utils/helpers.dart';
import '../../widgets/sync_refresh_button.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedStatus = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _statusFilters = [
    'All',
    'Paid',
    'Unpaid',
    'Partial',
    'Overdue',
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInvoices();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);

    try {
      final invoiceProvider = context.read<InvoiceProvider>();
      final customerProvider = context.read<CustomerProvider>();
      invoiceProvider.clearSearch();

      await invoiceProvider.loadInvoices(forceRefresh: true);
      await customerProvider.loadCustomers(forceRefresh: true);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        Helpers.showError(context, 'Failed to load invoices: $e');
      }
    }
  }

  List<Invoice> _getFilteredInvoices(List<Invoice> invoices) {
    List<Invoice> result = List.from(invoices);

    if (_selectedStatus.isNotEmpty && _selectedStatus != 'All') {
      final statusMap = {
        'Paid': Constants.invoiceStatusPaid,
        'Unpaid': Constants.invoiceStatusUnpaid,
        'Partial': Constants.invoiceStatusPartial,
        'Overdue': 'overdue',
      };
      final status = statusMap[_selectedStatus];
      if (status != null) {
        result = result.where((inv) {
          if (status == 'overdue') {
            return inv.isOverdue;
          }
          return inv.paymentStatus == status;
        }).toList();
      }
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((inv) {
        return inv.invoiceNumber.toLowerCase().contains(query) ||
            (inv.customerName?.toLowerCase().contains(query) ?? false) ||
            (inv.quoteNumber?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return result;
  }

  void _searchInvoices(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _filterByStatus(String status) {
    setState(() {
      _selectedStatus = status;
    });
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedStatus = '';
    });
  }

  Future<void> _updatePaymentStatus(String invoiceId, String status) async {
    setState(() => _isLoading = true);

    try {
      final invoiceProvider = context.read<InvoiceProvider>();
      double? amountPaid;

      if (status == Constants.invoiceStatusPaid) {
        final invoice = invoiceProvider.allInvoices.firstWhere((i) => i.id == invoiceId);
        amountPaid = invoice.total;
      }

      final success = await invoiceProvider.updatePaymentStatus(
        invoiceId,
        status,
        amountPaid: amountPaid,
      );

      setState(() => _isLoading = false);

      if (success) {
        await _loadInvoices();
        if (mounted) {
          Helpers.showSuccess(context, 'Payment status updated successfully');
        }
      } else {
        if (mounted) {
          Helpers.showError(
            context,
            invoiceProvider.errorMessage ?? 'Failed to update payment status',
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        Helpers.showError(context, 'Failed to update payment status: $e');
      }
    }
  }

  Future<void> _showPartialPaymentDialog(Invoice invoice) async {
    final amountController = TextEditingController();
    final balanceDue = invoice.total - invoice.amountPaid;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Partial Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Balance Due: ${_formatCurrency(balanceDue)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount Paid',
                hintText: 'Enter amount',
                prefixText: 'KSh ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final paidAmount =
                  double.tryParse(amountController.text.trim()) ?? 0;
              if (paidAmount <= 0) {
                Helpers.showError(context, 'Please enter a valid amount');
                return;
              }
              if (paidAmount > balanceDue) {
                Helpers.showError(context, 'Amount cannot exceed balance due');
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Record Payment'),
          ),
        ],
      ),
    );

    if (result != true) return;

    if (!mounted) return;
    final paidAmount = double.tryParse(amountController.text.trim()) ?? 0;
    
    setState(() => _isLoading = true);

    try {
      final invoiceProvider = context.read<InvoiceProvider>();
      final newStatus = (invoice.amountPaid + paidAmount) >= invoice.total
          ? Constants.invoiceStatusPaid
          : Constants.invoiceStatusPartial;

      final success = await invoiceProvider.updatePaymentStatus(
        invoice.id,
        newStatus,
        amountPaid: invoice.amountPaid + paidAmount,
      );

      setState(() => _isLoading = false);

      if (success) {
        await _loadInvoices();
        if (mounted) {
          Helpers.showSuccess(context, 'Partial payment recorded successfully');
        }
      } else {
        if (mounted) {
          Helpers.showError(
            context,
            invoiceProvider.errorMessage ?? 'Failed to record payment',
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        Helpers.showError(context, 'Failed to record payment: $e');
      }
    }
  }

  void _navigateToInvoiceDetails(Invoice invoice) {
    Navigator.pushNamed(
      context,
      '/admin/invoices/${invoice.id}',
    ).then((_) => _loadInvoices());
  }

  @override
  Widget build(BuildContext context) {
    final invoiceProvider = context.watch<InvoiceProvider>();
    final displayInvoices = _getFilteredInvoices(invoiceProvider.allInvoices);

    // Calculate stats
    final total = invoiceProvider.allInvoices.length;
    final paid = invoiceProvider.allInvoices.where((i) => i.isPaid).length;
    final unpaid = invoiceProvider.allInvoices.where((i) => i.isUnpaid).length;
    final overdue = invoiceProvider.allInvoices.where((i) => i.isOverdue).length;
    final totalAmount = invoiceProvider.allInvoices.fold(0.0, (sum, i) => sum + i.total);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Invoices',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/admin/invoices/create').then((value) {
                if (value == true) {
                  _loadInvoices();
                }
              });
            },
            tooltip: 'New Invoice',
          ),
          const SyncRefreshButton(color: Colors.white),
        ],
      ),
      drawer: const SidebarMenu(
        selectedIndex: 4,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildSearchAndFilterBar(),
            _buildStatsBar(
              total: total,
              paid: paid,
              unpaid: unpaid,
              overdue: overdue,
              totalAmount: totalAmount,
              filteredCount: displayInvoices.length,
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Loading invoices...',
                            style: TextStyle(color: AppColors.textLight),
                          ),
                        ],
                      ),
                    )
                   : displayInvoices.isEmpty
                  ? _buildEmptyState()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final availableW = constraints.maxWidth - 32;
                        final tableW = availableW > 1100 ? availableW : 1100.0;
                        return RefreshIndicator(
                          onRefresh: _loadInvoices,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: tableW,
                                child: _buildInvoiceTable(displayInvoices),
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
                  onChanged: _searchInvoices,
                  decoration: InputDecoration(
                    hintText: 'Search invoices by number, customer or quote...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textLight,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: AppColors.textLight,
                            ),
                            onPressed: () => _searchInvoices(''),
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
                onTap: () => _searchInvoices(_searchQuery),
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
              if (_searchQuery.isNotEmpty || _selectedStatus.isNotEmpty) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _clearFilters,
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.clear_all, color: AppColors.error),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _statusFilters.length,
              itemBuilder: (context, index) {
                final status = _statusFilters[index];
                final isSelected =
                    _selectedStatus == status ||
                    (_selectedStatus.isEmpty && status == 'All');
                return GestureDetector(
                  onTap: () {
                    _filterByStatus(status == 'All' ? '' : status);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
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
                          status,
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
    required int paid,
    required int unpaid,
    required int overdue,
    required double totalAmount,
    required int filteredCount,
  }) {
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
                  '$total total',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (paid > 0) _buildStatChip('$paid paid', AppColors.success),
              if (unpaid > 0)
                _buildStatChip('$unpaid unpaid', AppColors.warning),
              if (overdue > 0)
                _buildStatChip('$overdue overdue', AppColors.error),
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
              if (_searchQuery.isNotEmpty || _selectedStatus.isNotEmpty) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$filteredCount found',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.info,
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

  Widget _buildStatChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
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
  // INVOICE TABLE (FULL WIDTH)
  // ============================================

  Widget _buildInvoiceTable(List<Invoice> invoices) {
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
              Expanded(flex: 2, child: _buildHeaderCell('Invoice #')),
              Expanded(flex: 3, child: _buildHeaderCell('Customer')),
              Expanded(flex: 2, child: _buildHeaderCell('Quote #')),
              Expanded(flex: 2, child: _buildHeaderCell('Date', center: true)),
              Expanded(
                flex: 2,
                child: _buildHeaderCell('Due Date', center: true),
              ),
              Expanded(
                flex: 2,
                child: _buildHeaderCell('Paid', center: true),
              ),
              Expanded(
                flex: 2,
                child: _buildHeaderCell('Balance', center: true),
              ),
              Expanded(
                flex: 2,
                child: _buildHeaderCell('Total', center: true),
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
        ...invoices.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final invoice = entry.value;

          final statusColor = invoice.isPaid
              ? AppColors.success
              : invoice.isOverdue
              ? AppColors.error
              : invoice.isPartial
              ? AppColors.info
              : AppColors.warning;

          final statusIcon = invoice.isPaid
              ? Icons.check_circle
              : invoice.isOverdue
              ? Icons.warning
              : invoice.isPartial
              ? Icons.pending
              : Icons.pending;

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: invoice.isOverdue
                  ? AppColors.error.withValues(alpha: 0.05)
                  : index.isEven
                  ? Colors.white
                  : AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: invoice.isOverdue
                  ? Border.all(color: AppColors.error, width: 1)
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
                // Invoice Number
                Expanded(
                  flex: 2,
                  child: _buildCell(invoice.invoiceNumber, isBold: true),
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
                          Helpers.getInitials(invoice.customerName ?? 'U'),
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
                          invoice.customerName ?? 'Unknown',
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
                // Quote Number
                Expanded(
                  flex: 2,
                  child: _buildCell(
                    invoice.quoteNumber ?? 'N/A',
                    color: AppColors.textLight,
                  ),
                ),
                // Date
                Expanded(
                  flex: 2,
                  child: _buildCell(
                    _formatDate(invoice.createdAt),
                    center: true,
                    color: AppColors.textLight,
                  ),
                ),
                // Due Date
                Expanded(
                  flex: 2,
                  child: _buildCell(
                    invoice.dueDate != null
                        ? _formatDate(invoice.dueDate)
                        : 'N/A',
                    center: true,
                    color: invoice.isOverdue
                        ? AppColors.error
                        : AppColors.textLight,
                    isBold: invoice.isOverdue,
                  ),
                ),
                // Paid Amount
                Expanded(
                  flex: 2,
                  child: _buildCell(
                    _formatCurrency(invoice.amountPaid),
                    center: true,
                    color: invoice.amountPaid > 0 ? AppColors.success : AppColors.textLight,
                  ),
                ),
                // Balance Due
                Expanded(
                  flex: 2,
                  child: _buildCell(
                    _formatCurrency(invoice.effectiveBalanceDue),
                    center: true,
                    color: invoice.effectiveBalanceDue > 0 ? AppColors.error : AppColors.success,
                    isBold: invoice.effectiveBalanceDue > 0,
                  ),
                ),
                // Total Amount
                Expanded(
                  flex: 2,
                  child: _buildCell(
                    _formatCurrency(invoice.effectiveTotal),
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
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            invoice.displayStatus,
                            style: TextStyle(
                              fontSize: 11,
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
                      if (!invoice.isPaid)
                        IconButton(
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 18,
                            color: AppColors.success,
                          ),
                          onPressed: () => _updatePaymentStatus(
                            invoice.id,
                            Constants.invoiceStatusPaid,
                          ),
                          tooltip: 'Mark as Paid',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      IconButton(
                        icon: const Icon(
                          Icons.visibility,
                          size: 18,
                          color: AppColors.info,
                        ),
                        onPressed: () => _navigateToInvoiceDetails(invoice),
                        tooltip: 'View Details',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      if (!invoice.isPaid)
                        IconButton(
                          icon: const Icon(
                            Icons.payment,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          onPressed: () => _showPartialPaymentDialog(invoice),
                          tooltip: 'Partial Payment',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
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
  // EMPTY STATE
  // ============================================

  Widget _buildEmptyState() {
    final hasFilters = _searchQuery.isNotEmpty || _selectedStatus.isNotEmpty;

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
              hasFilters ? Icons.search_off : Icons.receipt_outlined,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'No matching invoices' : 'No invoices yet',
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
                : 'Convert approved quotes to invoices',
            style: TextStyle(fontSize: 14, color: AppColors.textLight),
          ),
          if (!hasFilters) ...[
            const SizedBox(height: 24),
            CustomButton(
              text: 'Go to Quotes',
              onPressed: () {
                Navigator.pushNamed(context, '/admin/quotes');
              },
              icon: Icons.receipt_long,
              variant: ButtonVariant.primary,
              size: ButtonSize.medium,
            ),
          ],
          if (hasFilters) ...[
            const SizedBox(height: 24),
            CustomButton(
              text: 'Clear Filters',
              onPressed: _clearFilters,
              icon: Icons.clear_all,
              variant: ButtonVariant.primary,
              size: ButtonSize.medium,
            ),
          ],
        ],
      ),
    );
  }
}
