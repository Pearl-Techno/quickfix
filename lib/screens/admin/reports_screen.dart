import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../providers/quote_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/customer_provider.dart';
import '../../widgets/sidebar_menu.dart';
import '../../widgets/sync_refresh_button.dart';
import '../../utils/helpers.dart';
import '../../models/invoice.dart';
import '../../models/quote.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String _selectedPeriod = 'This Year';
  final List<String> _periodOptions = [
    'This Month',
    'Last 30 Days',
    'This Quarter',
    'This Year',
    'All Time',
  ];

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
    try {
      final quoteProvider = context.read<QuoteProvider>();
      final invoiceProvider = context.read<InvoiceProvider>();
      final customerProvider = context.read<CustomerProvider>();

      await Future.wait([
        quoteProvider.loadQuotes(),
        invoiceProvider.loadInvoices(),
        customerProvider.loadCustomers(),
      ]);
    } catch (e) {
      if (mounted) {
        Helpers.showError(context, 'Failed to refresh report data: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatCurrency(double amount) {
    return 'KSh ${amount.toStringAsFixed(2)}';
  }

  List<Invoice> _filterInvoices(List<Invoice> allInvoices) {
    final now = DateTime.now();
    return allInvoices.where((invoice) {
      if (invoice.isVoid) return false;
      final date = invoice.createdAt ?? invoice.issuedDate ?? now;
      return _isDateInPeriod(date);
    }).toList();
  }

  List<Quote> _filterQuotes(List<Quote> allQuotes) {
    final now = DateTime.now();
    return allQuotes.where((quote) {
      final date = quote.createdAt ?? now;
      return _isDateInPeriod(date);
    }).toList();
  }

  bool _isDateInPeriod(DateTime date) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    
    switch (_selectedPeriod) {
      case 'This Month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        return date.isAfter(startOfMonth.subtract(const Duration(seconds: 1)));
      case 'Last 30 Days':
        final thirtyDaysAgo = startOfToday.subtract(const Duration(days: 30));
        return date.isAfter(thirtyDaysAgo.subtract(const Duration(seconds: 1)));
      case 'This Quarter':
        final currentQuarterMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        final startOfQuarter = DateTime(now.year, currentQuarterMonth, 1);
        return date.isAfter(startOfQuarter.subtract(const Duration(seconds: 1)));
      case 'This Year':
        final startOfYear = DateTime(now.year, 1, 1);
        return date.isAfter(startOfYear.subtract(const Duration(seconds: 1)));
      case 'All Time':
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final quoteProvider = context.watch<QuoteProvider>();
    final invoiceProvider = context.watch<InvoiceProvider>();
    
    final invoices = _filterInvoices(invoiceProvider.allInvoices);
    final quotes = _filterQuotes(quoteProvider.allQuotes);

    // Calculate metrics
    final double grossRevenue = invoices.fold(0.0, (sum, i) => sum + i.total);
    final double collectedPayments = invoices.fold(0.0, (sum, i) => sum + i.amountPaid);
    final double outstandingBalance = invoices.fold(0.0, (sum, i) => sum + i.balanceDue);
    
    final totalQuotes = quotes.length;
    final approvedOrConvertedQuotes = quotes.where((q) => q.isApproved || q.isConverted).length;
    final double conversionRate = totalQuotes > 0 
        ? (approvedOrConvertedQuotes / totalQuotes) * 100 
        : 0.0;

    final double avgInvoiceValue = invoices.isNotEmpty 
        ? grossRevenue / invoices.length 
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Reports & Analytics',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          const SyncRefreshButton(color: Colors.white),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              Helpers.showSnackBar(context, 'Exporting report...', backgroundColor: AppColors.info);
            },
            tooltip: 'Export Data',
          ),
        ],
      ),
      drawer: const SidebarMenu(
        selectedIndex: 11,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPeriodSelector(),
                      const SizedBox(height: 20),
                      _buildSummaryGrid(
                        grossRevenue: grossRevenue,
                        collectedPayments: collectedPayments,
                        outstandingBalance: outstandingBalance,
                        conversionRate: conversionRate,
                        avgInvoiceValue: avgInvoiceValue,
                        invoiceCount: invoices.length,
                        quoteCount: totalQuotes,
                      ),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 900;
                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildRevenueChart(invoices),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: _buildQuotesStatusDistribution(quotes),
                                ),
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                _buildRevenueChart(invoices),
                                const SizedBox(height: 20),
                                _buildQuotesStatusDistribution(quotes),
                              ],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 900;
                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildTopCustomers(invoices),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildHighValueInvoices(invoices),
                                ),
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                _buildTopCustomers(invoices),
                                const SizedBox(height: 20),
                                _buildHighValueInvoices(invoices),
                              ],
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.date_range, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Reporting Period',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          DropdownButton<String>(
            value: _selectedPeriod,
            underline: const SizedBox(),
            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
            borderRadius: BorderRadius.circular(12),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.primary,
            ),
            items: _periodOptions.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedPeriod = newValue;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid({
    required double grossRevenue,
    required double collectedPayments,
    required double outstandingBalance,
    required double conversionRate,
    required double avgInvoiceValue,
    required int invoiceCount,
    required int quoteCount,
  }) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 900 ? 5 : 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: MediaQuery.of(context).size.width > 900 ? 1.4 : 1.6,
      children: [
        _buildSummaryCard(
          title: 'Gross Sales',
          value: _formatCurrency(grossRevenue),
          icon: Icons.monetization_on,
          color: AppColors.primary,
          subtext: '$invoiceCount invoices issued',
        ),
        _buildSummaryCard(
          title: 'Payments Collected',
          value: _formatCurrency(collectedPayments),
          icon: Icons.check_circle,
          color: AppColors.success,
          subtext: grossRevenue > 0
              ? '${(collectedPayments / grossRevenue * 100).toInt()}% collection rate'
              : '0% collection rate',
        ),
        _buildSummaryCard(
          title: 'Outstanding Balance',
          value: _formatCurrency(outstandingBalance),
          icon: Icons.hourglass_empty,
          color: AppColors.error,
          subtext: 'Unpaid and partial invoices',
        ),
        _buildSummaryCard(
          title: 'Quote Conversion',
          value: '${conversionRate.toStringAsFixed(1)}%',
          icon: Icons.trending_up,
          color: AppColors.converted,
          subtext: '$quoteCount quotes processed',
        ),
        _buildSummaryCard(
          title: 'Average Invoice',
          value: _formatCurrency(avgInvoiceValue),
          icon: Icons.analytics,
          color: AppColors.warning,
          subtext: 'Average revenue per project',
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtext,
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
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textLight,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtext,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textLight.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart(List<Invoice> invoices) {
    // Generate data for the last 6 months
    final now = DateTime.now();
    final List<Map<String, dynamic>> monthlySales = [];
    final monthFormat = DateFormat('MMM yy');

    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final monthInvoices = invoices.where((inv) {
        final date = inv.createdAt ?? now;
        return date.year == monthDate.year && date.month == monthDate.month;
      });
      final total = monthInvoices.fold(0.0, (sum, inv) => sum + inv.total);
      monthlySales.add({
        'label': monthFormat.format(monthDate),
        'amount': total,
      });
    }

    final double maxAmount = monthlySales.fold(0.0, (max, entry) {
      final val = entry['amount'] as double;
      return val > max ? val : max;
    });

    return Container(
      padding: const EdgeInsets.all(20),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue Trend (Last 6 Months)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: monthlySales.map((entry) {
                final amount = entry['amount'] as double;
                final label = entry['label'] as String;
                final percentage = maxAmount > 0 ? (amount / maxAmount) : 0.0;
                
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      amount > 1000 ? '${(amount / 1000).toStringAsFixed(1)}k' : amount.toInt().toString(),
                      style: TextStyle(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 24,
                      height: (120 * percentage).clamp(6.0, 120.0),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.text),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotesStatusDistribution(List<Quote> quotes) {
    final total = quotes.length;
    final draft = quotes.where((q) => q.isDraft).length;
    final sent = quotes.where((q) => q.isSent).length;
    final approved = quotes.where((q) => q.isApproved).length;
    final converted = quotes.where((q) => q.isConverted).length;
    final rejected = quotes.where((q) => q.isRejected).length;

    Widget statusRow(String name, int count, Color color) {
      final double percent = total > 0 ? count / total : 0.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
                    ),
                  ],
                ),
                Text(
                  '$count (${(percent * 100).toInt()}%)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLight),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quotation Conversion Pipeline',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
          ),
          const SizedBox(height: 20),
          statusRow('Converted to Invoice', converted, AppColors.converted),
          statusRow('Approved', approved, AppColors.approved),
          statusRow('Sent', sent, AppColors.sent),
          statusRow('Draft', draft, AppColors.draft),
          statusRow('Rejected', rejected, AppColors.rejected),
        ],
      ),
    );
  }

  Widget _buildTopCustomers(List<Invoice> invoices) {
    // Aggregate revenue by customer
    final Map<String, double> customerRevenue = {};
    final Map<String, String> customerNames = {};

    for (var inv in invoices) {
      final customerId = inv.customerId;
      final name = inv.customerName ?? 'Unknown Customer';
      customerRevenue[customerId] = (customerRevenue[customerId] ?? 0.0) + inv.total;
      customerNames[customerId] = name;
    }

    final sortedCustomers = customerRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topCustomers = sortedCustomers.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Customers by Revenue',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
          ),
          const SizedBox(height: 16),
          if (topCustomers.isEmpty)
            const SizedBox(
              height: 150,
              child: Center(
                child: Text('No invoice data available', style: TextStyle(color: AppColors.textLight)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topCustomers.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = topCustomers[index];
                final name = customerNames[entry.key] ?? 'Unknown';
                final total = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatCurrency(total),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHighValueInvoices(List<Invoice> invoices) {
    final highValueInvoices = List<Invoice>.from(invoices)
      ..sort((a, b) => b.total.compareTo(a.total));
    
    final topInvoices = highValueInvoices.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Highest Value Invoices',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
          ),
          const SizedBox(height: 16),
          if (topInvoices.isEmpty)
            const SizedBox(
              height: 150,
              child: Center(
                child: Text('No invoice data available', style: TextStyle(color: AppColors.textLight)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topInvoices.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final invoice = topInvoices[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.receipt_outlined, color: AppColors.secondary, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invoice.invoiceNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              invoice.customerName ?? 'Unknown Customer',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatCurrency(invoice.total),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
