import 'package:flutter/material.dart';
import '../models/quote.dart';
import '../config/app_colors.dart';
import '../utils/helpers.dart';

class QuoteCard extends StatelessWidget {
  final Quote quote;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showCustomerAvatar;
  final bool showSiteMeasurements;
  final bool showItemCount;
  final bool showValidityInfo;
  final bool compact;
  final double? elevation;
  final Color? backgroundColor;
  final EdgeInsets? padding;

  const QuoteCard({
    super.key,
    required this.quote,
    this.onTap,
    this.onLongPress,
    this.showCustomerAvatar = true,
    this.showSiteMeasurements = true,
    this.showItemCount = true,
    this.showValidityInfo = true,
    this.compact = false,
    this.elevation,
    this.backgroundColor,
    this.padding,
  });

  // Simple date formatter without intl dependency
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

  // Simple currency formatter without intl dependency
  String _formatCurrency(double amount) {
    return 'KSh ${amount.toStringAsFixed(2)}';
  }

  // Get days remaining
  String _getDaysRemaining() {
    if (quote.expiryDate == null) return '';
    final days = DateTime.now().difference(quote.expiryDate!).inDays;
    if (days < 0) return '${days.abs()} days overdue';
    if (days == 0) return 'Expires today';
    return '$days days left';
  }

  Color _getDaysRemainingColor() {
    if (quote.expiryDate == null) return AppColors.textLight;
    final days = DateTime.now().difference(quote.expiryDate!).inDays;
    if (days < 0) return AppColors.error;
    if (days <= 3) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = Helpers.getStatusColor(quote.status);
    final statusIcon = Helpers.getStatusIcon(quote.status);
    final isExpired = quote.isExpired;

    return Card(
      elevation: elevation ?? 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isExpired
            ? BorderSide(color: AppColors.error.withValues(alpha: 0.3))
            : BorderSide.none,
      ),
      shadowColor: Colors.black.withValues(alpha: 0.05),
      color: backgroundColor ?? (isExpired ? AppColors.errorBackground : null),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: compact
              ? _buildCompactContent(statusColor, statusIcon)
              : _buildFullContent(statusColor, statusIcon),
        ),
      ),
    );
  }

  // ============================================
  // FULL CONTENT
  // ============================================

  Widget _buildFullContent(Color statusColor, IconData statusIcon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: Quote number + Status
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  quote.quoteNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 12, color: statusColor),
                  const SizedBox(width: 5),
                  Text(
                    quote
                        .displayStatus, // Fixed: changed from statusDisplay to displayStatus
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (quote.hasTitle) ...[
          const SizedBox(height: 6),
          Text(
            quote.title!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 10),

        // Customer info
        Row(
          children: [
            if (showCustomerAvatar) ...[
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  quote.customerName?.isNotEmpty == true
                      ? quote.customerName![0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quote.customerName ?? 'Unknown Customer',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showItemCount && quote.items != null)
                    Text(
                      '${quote.items!.length} items',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Date, amount, and validity
        Row(
          children: [
            // Date
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 12,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(quote.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Total amount
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _formatCurrency(quote.grandTotal),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),

        // Validity info
        if (showValidityInfo && quote.expiryDate != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getDaysRemainingColor().withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: _getDaysRemainingColor(),
                ),
                const SizedBox(width: 4),
                Text(
                  _getDaysRemaining(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _getDaysRemainingColor(),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• Valid until ${_formatDate(quote.expiryDate)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Site measurements
        if (showSiteMeasurements &&
            quote.siteMeasurements != null &&
            quote.siteMeasurements!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.straighten,
                  size: 14,
                  color: AppColors.textLight,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    quote.siteMeasurements!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Notes preview
        if (quote.notes != null && quote.notes!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.note, size: 14, color: AppColors.textLight),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    quote.notes!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ============================================
  // COMPACT CONTENT
  // ============================================

  Widget _buildCompactContent(Color statusColor, IconData statusIcon) {
    return Row(
      children: [
        // Status indicator
        Container(
          width: 4,
          height: 50,
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),

        // Main content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    quote.quoteNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatCurrency(quote.grandTotal),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              if (quote.hasTitle) ...[
                const SizedBox(height: 2),
                Text(
                  quote.title!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    quote.customerName ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      quote
                          .displayStatus, // Fixed: changed from statusDisplay to displayStatus
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================
// QUOTE CARD LIST EXTENSIONS
// ============================================

class QuoteCardList extends StatelessWidget {
  final List<Quote> quotes;
  final Function(Quote)? onQuoteTap;
  final Function(Quote)? onQuoteLongPress;
  final bool compact;
  final bool showCustomerAvatar;
  final bool showSiteMeasurements;
  final bool showItemCount;
  final bool showValidityInfo;
  final EdgeInsets? padding;
  final double? elevation;
  final Color? backgroundColor;

  const QuoteCardList({
    super.key,
    required this.quotes,
    this.onQuoteTap,
    this.onQuoteLongPress,
    this.compact = false,
    this.showCustomerAvatar = true,
    this.showSiteMeasurements = true,
    this.showItemCount = true,
    this.showValidityInfo = true,
    this.padding,
    this.elevation,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (quotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: AppColors.textLight.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No quotes found',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new quote to get started',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textLight.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: quotes.length,
      padding:
          padding ?? const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemBuilder: (context, index) {
        final quote = quotes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: QuoteCard(
            quote: quote,
            onTap: onQuoteTap != null ? () => onQuoteTap!(quote) : null,
            onLongPress: onQuoteLongPress != null
                ? () => onQuoteLongPress!(quote)
                : null,
            compact: compact,
            showCustomerAvatar: showCustomerAvatar,
            showSiteMeasurements: showSiteMeasurements,
            showItemCount: showItemCount,
            showValidityInfo: showValidityInfo,
            elevation: elevation,
            backgroundColor: backgroundColor,
          ),
        );
      },
    );
  }
}
