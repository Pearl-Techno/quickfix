// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../providers/customer_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/quote_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../models/quote.dart';
import '../../models/quote_item.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_dropdown.dart';
import '../../utils/helpers.dart';
import '../../utils/formatters.dart';
import '../../widgets/quote_preview_dialog.dart';

// Extended QuoteItem with section support
class ExtendedQuoteItem extends QuoteItem {
  final bool isPriceEdited;

  ExtendedQuoteItem({
    required super.id,
    required super.quoteId,
    super.productId,
    required super.itemType,
    required super.description,
    required super.quantity,
    required super.unitPrice,
    super.discount = 0,
    super.tax = 0,
    required super.total,
    super.createdAt,
    super.productName,
    super.section,
    this.isPriceEdited = false,
  });

  factory ExtendedQuoteItem.fromQuoteItem(
    QuoteItem item, {
    String? section,
    bool isPriceEdited = false,
  }) {
    return ExtendedQuoteItem(
      id: item.id,
      quoteId: item.quoteId,
      productId: item.productId,
      itemType: item.itemType,
      description: item.description,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      discount: item.discount,
      tax: item.tax,
      total: item.total,
      createdAt: item.createdAt,
      productName: item.productName,
      section: section ?? item.section,
      isPriceEdited: isPriceEdited,
    );
  }
}

class CreateQuoteScreen extends StatefulWidget {
  final String? quoteId;
  final bool isInvoice;
  const CreateQuoteScreen({super.key, this.quoteId, this.isInvoice = false});

  @override
  State<CreateQuoteScreen> createState() => _CreateQuoteScreenState();
}

class _CreateQuoteScreenState extends State<CreateQuoteScreen>
    with SingleTickerProviderStateMixin {
  final _notesController = TextEditingController();
  final _siteMeasurementsController = TextEditingController();
  final _productSearchController = TextEditingController();
  final _sectionNameController = TextEditingController();
  final _furtherDescriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _customDescriptionController = TextEditingController();
  final _customUnitPriceController = TextEditingController();
  final _discountController = TextEditingController();

  Customer? _selectedCustomer;
  Product? _selectedProduct;
  String _itemType = Constants.itemTypeStock;
  List<Product> _filteredProducts = [];
  bool _applyTax = false;
  String _selectedSection = '';
  bool _isSubmitting = false;
  bool _useCustomPrice = false;
  final _customPriceController = TextEditingController();

  bool _useDirectClient = false;
  final _directClientNameController = TextEditingController();
  final _directClientPhoneController = TextEditingController();
  final _directClientEmailController = TextEditingController();
  final _directClientAddressController = TextEditingController();
  final _directClientSiteLocationController = TextEditingController();
  final _scopeController = TextEditingController();
  final _termsController = TextEditingController();
  DateTime? _dueDate;

  final List<ExtendedQuoteItem> _items = [];
  final List<String> _sections = [];
  double _subtotal = 0;
  double _tax = 0;
  double _total = 0;

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
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
    _productSearchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _productSearchController.removeListener(_filterProducts);
    _productSearchController.dispose();
    _notesController.dispose();
    _siteMeasurementsController.dispose();
    _sectionNameController.dispose();
    _customPriceController.dispose();
    _customDescriptionController.dispose();
    _customUnitPriceController.dispose();
    _directClientNameController.dispose();
    _directClientPhoneController.dispose();
    _directClientEmailController.dispose();
    _directClientAddressController.dispose();
    _directClientSiteLocationController.dispose();
    _scopeController.dispose();
    _termsController.dispose();
    _furtherDescriptionController.dispose();
    _quantityController.dispose();
    _discountController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final customerProvider = context.read<CustomerProvider>();
    customerProvider.clearSearch();
    await customerProvider.loadCustomers();
    if (!mounted) return;
    final productProvider = context.read<ProductProvider>();
    productProvider.clearAllFilters();
    await productProvider.loadProducts();
    if (!mounted) return;
    _filterProducts();
    _applyTax = context.read<SettingsProvider>().vatEnabled;

    if (widget.quoteId != null) {
      final quoteProvider = context.read<QuoteProvider>();
      final quote = await quoteProvider.getQuote(widget.quoteId!);
      if (!mounted) return;
      if (quote != null) {
        final customerProvider = context.read<CustomerProvider>();
        _selectedCustomer = customerProvider.customers.firstWhere(
          (c) => c.id == quote.customerId,
          orElse: () => Customer(
            id: quote.customerId,
            name: quote.customerName ?? 'Unknown',
            phone: '',
            email: '',
          ),
        );
        _scopeController.text = quote.scope ?? '';
        _notesController.text = quote.notes ?? '';
        _termsController.text = quote.terms ?? '';
        _siteMeasurementsController.text = quote.siteMeasurements ?? '';
        _dueDate = quote.expiryDate;
        _applyTax = quote.tax > 0;

        _items.clear();
        _sections.clear();
        if (quote.items != null) {
          for (final item in quote.items!) {
            _items.add(ExtendedQuoteItem.fromQuoteItem(
              item,
              section: item.section ?? 'General',
            ));
            if (item.section != null && !_sections.contains(item.section)) {
              _sections.add(item.section!);
            }
          }
        }
        for (final defaultSec in ['Materials', 'Labour', 'Other']) {
          if (!_sections.contains(defaultSec)) {
            _sections.add(defaultSec);
          }
        }
        _selectedSection = '';
        _calculateTotals();
      }
    } else {
      // New quote
      _sections.clear();
      _sections.addAll(['Materials', 'Labour', 'Other']);
      _selectedSection = '';
    }
  }

  void _filterProducts() {
    if (!mounted) return;
    final productProvider = context.read<ProductProvider>();
    final query = _productSearchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      _filteredProducts = productProvider.products;
    } else {
      _filteredProducts = productProvider.products.where((product) {
        return product.name.toLowerCase().contains(query) ||
            product.category.toLowerCase().contains(query);
      }).toList();
    }
    setState(() {});
  }

  void _toggleCustomPrice() {
    setState(() {
      _useCustomPrice = !_useCustomPrice;
      if (_useCustomPrice && _selectedProduct != null) {
        _customPriceController.text = _selectedProduct!.unitPrice.toString();
      } else {
        _customPriceController.clear();
      }
    });
  }

  void _addSection() {
    final sectionName = _sectionNameController.text.trim();
    if (sectionName.isEmpty) {
      Helpers.showError(context, 'Please enter a section name');
      return;
    }
    if (_sections.contains(sectionName)) {
      Helpers.showError(context, 'Section already exists');
      return;
    }
    setState(() {
      _sections.add(sectionName);
      _selectedSection = sectionName;
      _sectionNameController.clear();
    });
    Helpers.showSuccess(context, 'Section "$sectionName" added');
  }

  void _removeSection(String section) {
    final hasItems = _items.any((item) => item.section == section);
    if (hasItems) {
      Helpers.showError(context, 'Cannot remove section. Remove items first.');
      return;
    }
    setState(() {
      _sections.remove(section);
      if (_selectedSection == section) {
        _selectedSection = _sections.isNotEmpty ? _sections.first : '';
      }
    });
  }

  void _addItem() {
    if (_selectedCustomer == null && !_useDirectClient) {
      Helpers.showError(context, 'Please select a customer first');
      return;
    }



    if (_itemType == Constants.itemTypeStock && _selectedProduct == null) {
      Helpers.showError(context, 'Please select a product');
      return;
    }

    String description = '';
    double unitPrice = 0;
    bool isPriceEdited = false;

    if (_itemType == Constants.itemTypeStock && _selectedProduct != null) {
      description = _selectedProduct!.name;
      final furtherDesc = _furtherDescriptionController.text.trim();
      if (furtherDesc.isNotEmpty) {
        description += ' - $furtherDesc';
      }

      if (_useCustomPrice) {
        final customPrice = double.tryParse(_customPriceController.text.trim());
        if (customPrice != null && customPrice > 0) {
          unitPrice = customPrice;
          isPriceEdited = true;
        } else {
          Helpers.showError(context, 'Please enter a valid custom price');
          return;
        }
      } else {
        unitPrice = _selectedProduct!.unitPrice;
      }
    } else {
      // Labour or Transport custom input
      final customDesc = _customDescriptionController.text.trim();
      final customPrice = double.tryParse(_customUnitPriceController.text.trim());

      if (customDesc.isEmpty) {
        Helpers.showError(context, 'Please enter a description');
        return;
      }
      if (customPrice == null || customPrice <= 0) {
        Helpers.showError(context, 'Please enter a valid price / rate');
        return;
      }

      description = customDesc;
      unitPrice = customPrice;
      isPriceEdited = true;
    }

    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;
    final discountStr = _discountController.text.trim();
    double discount = 0;
    final subtotal = unitPrice * quantity;
    if (discountStr.isNotEmpty) {
      if (discountStr.endsWith('%')) {
        final pctStr = discountStr.substring(0, discountStr.length - 1).trim();
        final pct = double.tryParse(pctStr) ?? 0;
        discount = (subtotal * pct) / 100;
      } else {
        discount = double.tryParse(discountStr) ?? 0;
      }
    }

    final effectiveSection = _selectedSection.trim().isNotEmpty ? _selectedSection : 'General';

    final item = ExtendedQuoteItem(
      id: Helpers.generateId(),
      quoteId: '',
      productId: _itemType == Constants.itemTypeStock ? _selectedProduct?.id : null,
      itemType: _itemType,
      description: description,
      quantity: quantity,
      unitPrice: unitPrice,
      discount: discount,
      total: subtotal - discount,
      section: effectiveSection,
      isPriceEdited: isPriceEdited,
    );

    setState(() {
      _items.add(item);
      if (!_sections.contains(effectiveSection)) {
        _sections.add(effectiveSection);
      }
      _calculateTotals();
    });

    Helpers.showSuccess(context, 'Item added${_selectedSection.isNotEmpty ? ' to $_selectedSection' : ''}');
    setState(() {
      _selectedProduct = null;
      _quantityController.text = '1';
      _discountController.clear();
      _productSearchController.clear();
      _useCustomPrice = false;
      _customPriceController.clear();
      _furtherDescriptionController.clear();
      _customDescriptionController.clear();
      _customUnitPriceController.clear();
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _calculateTotals();
    });
  }

  void _calculateTotals() {
    _subtotal = _items.fold(0.0, (sum, item) => sum + item.total);
    _tax = _applyTax ? _subtotal * Constants.taxRate : 0;
    _total = _subtotal + _tax;
  }

  void _toggleTax(bool value) {
    setState(() {
      _applyTax = value;
      _calculateTotals();
    });
  }

  Future<void> _previewQuote() async {
    Customer? targetCustomer = _selectedCustomer;
    if (_useDirectClient) {
      if (_directClientNameController.text.trim().isEmpty) {
        Helpers.showError(context, 'Please enter direct customer name');
        return;
      }
      targetCustomer = Customer(
        id: 'temp-direct-client',
        name: _directClientNameController.text.trim(),
        phone: _directClientPhoneController.text.trim().isEmpty
            ? null
            : _directClientPhoneController.text.trim(),
        email: _directClientEmailController.text.trim().isEmpty
            ? null
            : _directClientEmailController.text.trim(),
        address: _directClientAddressController.text.trim().isEmpty
            ? null
            : _directClientAddressController.text.trim(),
        siteLocation: _directClientSiteLocationController.text.trim().isEmpty
            ? null
            : _directClientSiteLocationController.text.trim(),
      );
    } else if (targetCustomer == null) {
      Helpers.showError(context, 'Please select a customer');
      return;
    }

    final quoteData = {
      'customer': targetCustomer,
      'items': _items,
      'subtotal': _subtotal,
      'tax': _tax,
      'total': _total,
      'scope': _scopeController.text.trim(),
      'notes': _notesController.text.trim(),
      'siteMeasurements': _siteMeasurementsController.text.trim(),
      'applyTax': _applyTax,
      'sections': _sections,
    };

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => QuotePreviewDialog(
        quoteData: quoteData,
        isInvoice: widget.isInvoice,
      ),
    );

    if (result == true) {
      _saveQuote();
    }
  }

  Future<void> _saveQuote() async {
    if (!_useDirectClient && _selectedCustomer == null) {
      Helpers.showError(context, 'Please select a customer');
      return;
    }
    if (_useDirectClient && _directClientNameController.text.trim().isEmpty) {
      Helpers.showError(context, 'Please enter direct customer name');
      return;
    }

    if (_items.isEmpty) {
      Helpers.showError(context, 'Please add at least one item');
      return;
    }

    setState(() => _isSubmitting = true);

    final authProvider = context.read<AuthProvider>();
    final quoteProvider = context.read<QuoteProvider>();
    final customerProvider = context.read<CustomerProvider>();
    final invoiceProvider = context.read<InvoiceProvider>();

    Customer? targetCustomer = _selectedCustomer;

    if (_useDirectClient) {
      try {
        targetCustomer = await customerProvider.createCustomer(
          name: _directClientNameController.text.trim(),
          phone: _directClientPhoneController.text.trim().isEmpty
              ? null
              : _directClientPhoneController.text.trim(),
          email: _directClientEmailController.text.trim().isEmpty
              ? null
              : _directClientEmailController.text.trim(),
          address: _directClientAddressController.text.trim().isEmpty
              ? null
              : _directClientAddressController.text.trim(),
          siteLocation: _directClientSiteLocationController.text.trim().isEmpty
              ? null
              : _directClientSiteLocationController.text.trim(),
        );
        if (!context.mounted) return;
        if (targetCustomer == null) {
          throw Exception(customerProvider.errorMessage ?? 'Failed to create customer');
        }
      } catch (e) {
        setState(() => _isSubmitting = false);
        if (context.mounted) {
          Helpers.showError(context, 'Failed to create direct client: $e');
        }
        return;
      }
    }

    final quoteItems = _items.map((item) {
      return QuoteItem(
        id: item.id,
        quoteId: item.quoteId,
        productId: item.productId,
        itemType: item.itemType,
        description: item.description,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        discount: item.discount,
        total: item.total,
        createdAt: item.createdAt,
        productName: item.productName,
        section: item.section,
      );
    }).toList();

    if (widget.isInvoice) {
      final invoice = await invoiceProvider.createDirectInvoice(
        customerId: targetCustomer!.id,
        userId: authProvider.currentUser!.id,
        items: quoteItems,
        scope: _scopeController.text.trim().isEmpty
            ? null
            : _scopeController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        terms: _termsController.text.trim().isEmpty
            ? null
            : _termsController.text.trim(),
        dueDate: _dueDate,
        applyTax: _applyTax,
      );

      setState(() => _isSubmitting = false);

      if (!context.mounted) return;

      if (invoice != null) {
        Helpers.showSuccess(context, 'Invoice created successfully');
        Navigator.pop(context, true);
      } else {
        Helpers.showError(
          context,
          invoiceProvider.errorMessage ?? 'Failed to create invoice',
        );
      }
      return;
    }

    final Quote? quote;
    if (widget.quoteId != null) {
      quote = await quoteProvider.updateQuote(
        quoteId: widget.quoteId!,
        items: quoteItems,
        scope: _scopeController.text.trim().isEmpty
            ? null
            : _scopeController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        terms: _termsController.text.trim().isEmpty
            ? null
            : _termsController.text.trim(),
        siteMeasurements: _siteMeasurementsController.text.trim().isEmpty
            ? null
            : _siteMeasurementsController.text.trim(),
        dueDate: _dueDate,
        applyTax: _applyTax,
      );
    } else {
      quote = await quoteProvider.createQuote(
        customerId: targetCustomer!.id,
        userId: authProvider.currentUser!.id,
        items: quoteItems,
        scope: _scopeController.text.trim().isEmpty
            ? null
            : _scopeController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        terms: _termsController.text.trim().isEmpty
            ? null
            : _termsController.text.trim(),
        siteMeasurements: _siteMeasurementsController.text.trim().isEmpty
            ? null
            : _siteMeasurementsController.text.trim(),
        dueDate: _dueDate,
        applyTax: _applyTax,
      );
    }

    setState(() => _isSubmitting = false);

    if (!context.mounted) return;

    if (quote != null) {
      Helpers.showSuccess(
        context,
        widget.quoteId != null
            ? 'Quote updated successfully'
            : 'Quote created successfully',
      );
      Navigator.pop(context, true);
    } else {
      Helpers.showError(
        context,
        quoteProvider.errorMessage ??
            (widget.quoteId != null
                ? 'Failed to update quote'
                : 'Failed to create quote'),
      );
    }
  }

  void _showExitConfirmation() {
    if (_items.isEmpty && _selectedCustomer == null) {
      Navigator.pop(context);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.isInvoice ? 'Exit Invoice Creation?' : 'Exit Quote Creation?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = context.watch<CustomerProvider>();
    final productProvider = context.watch<ProductProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.receipt_long,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.isInvoice
                  ? 'Create Invoice'
                  : (widget.quoteId != null ? 'Edit Quote' : 'Create Quote'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility),
            onPressed: _previewQuote,
            tooltip: widget.isInvoice ? 'Preview Invoice' : 'Preview Quote',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveQuote,
            tooltip: widget.isInvoice ? 'Save Invoice' : 'Save Quote',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 950) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 20),
                          _buildCustomerCard(customerProvider),
                          const SizedBox(height: 16),
                          _buildSectionsCard(),
                          const SizedBox(height: 16),
                          _buildAddItemsCard(productProvider),
                          if (_items.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildItemsTable(),
                          ],
                        ],
                      ),
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: AppColors.border.withValues(alpha: 0.5),
                  ),
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAdditionalInfoCard(),
                          const SizedBox(height: 16),
                          _buildTotalsCard(),
                          const SizedBox(height: 20),
                          _buildDesktopActionCard(),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildCustomerCard(customerProvider),
                    const SizedBox(height: 16),
                    _buildSectionsCard(),
                    const SizedBox(height: 16),
                    _buildAddItemsCard(productProvider),
                    if (_items.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildItemsTable(),
                    ],
                    const SizedBox(height: 16),
                    _buildAdditionalInfoCard(),
                    const SizedBox(height: 16),
                    _buildTotalsCard(),
                    const SizedBox(height: 20),
                    _buildActionButtons(),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create New Quote',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Select customer, add sections and items',
                  style: TextStyle(fontSize: 13, color: AppColors.textLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(CustomerProvider customerProvider) {
    return _buildCard(
      title: 'Customer Information',
      icon: Icons.person_outline,
      iconColor: AppColors.primary,
      tag: _useDirectClient
          ? (_directClientNameController.text.isNotEmpty ? 'Direct Input' : 'Incomplete')
          : (_selectedCustomer != null ? 'Selected' : null),
      tagColor: _useDirectClient
          ? (_directClientNameController.text.isNotEmpty ? AppColors.info : AppColors.warning)
          : AppColors.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _useDirectClient = false;
                      _selectedCustomer = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_useDirectClient
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : Colors.white,
                      border: Border.all(
                        color: !_useDirectClient
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(8),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Use System Client',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: !_useDirectClient
                              ? AppColors.primary
                              : AppColors.textLight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _useDirectClient = true;
                      _selectedCustomer = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _useDirectClient
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : Colors.white,
                      border: Border.all(
                        color: _useDirectClient
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(8),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Type Details Direct',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _useDirectClient
                              ? AppColors.primary
                              : AppColors.textLight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          if (!_useDirectClient) ...[
            CustomDropdown<Customer?>(
              value: _selectedCustomer,
              items: customerProvider.customers.map((customer) {
                return DropdownMenuItem<Customer?>(
                  value: customer,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            if (customer.phone != null)
                              Text(
                                customer.phone!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textLight,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              label: 'Select Customer *',
              hint: 'Choose a customer',
              onChanged: (value) {
                setState(() {
                  _selectedCustomer = value;
                });
              },
              validator: (value) {
                if (value == null) return 'Please select a customer';
                return null;
              },
              prefixIcon: const Icon(Icons.person_outline, size: 20),
            ),
            if (_selectedCustomer != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          _selectedCustomer!.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    if (_selectedCustomer!.hasPhone) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 14, color: AppColors.textLight),
                          const SizedBox(width: 8),
                          Text(
                            _selectedCustomer!.phone!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_selectedCustomer!.hasEmail) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.email, size: 14, color: AppColors.textLight),
                          const SizedBox(width: 8),
                          Text(
                            _selectedCustomer!.email!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_selectedCustomer!.hasSiteLocation) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: AppColors.textLight),
                          const SizedBox(width: 8),
                          Text(
                            _selectedCustomer!.siteLocation!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (customerProvider.customers.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.addCustomer);
                  },
                  child: const Text('Add New Customer'),
                ),
              ),
          ] else ...[
            CustomTextField(
              controller: _directClientNameController,
              label: 'Client Name *',
              hint: 'Enter client name',
              prefixIcon: const Icon(Icons.person, size: 20),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _directClientPhoneController,
              label: 'Phone Number',
              hint: 'e.g., 0700 000 000',
              prefixIcon: const Icon(Icons.phone, size: 20),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _directClientEmailController,
              label: 'Email Address',
              hint: 'e.g., client@example.com',
              prefixIcon: const Icon(Icons.email, size: 20),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _directClientAddressController,
              label: 'Address',
              hint: 'Enter address',
              prefixIcon: const Icon(Icons.location_on, size: 20),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _directClientSiteLocationController,
              label: 'Site Location',
              hint: 'Enter site location',
              prefixIcon: const Icon(Icons.business, size: 20),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionsCard() {
    return _buildCard(
      title: 'Sections / Categories',
      icon: Icons.folder,
      iconColor: AppColors.info,
      tag: _sections.isNotEmpty ? '${_sections.length} sections' : null,
      tagColor: AppColors.info,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _sectionNameController,
                  label: 'Section Name',
                  hint: 'e.g., Kitchen, Bathroom, Plumbing',
                  prefixIcon: const Icon(Icons.folder_open, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 80,
                height: 44,
                child: CustomButton(
                  text: 'Add',
                  onPressed: _addSection,
                  icon: Icons.add,
                  fullWidth: true,
                  variant: ButtonVariant.secondary,
                  size: ButtonSize.small,
                ),
              ),
            ],
          ),
          if (_sections.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sections.map((section) {
                final isSelected = section == _selectedSection;
                final itemCount = _items
                    .where((item) => item.section == section)
                    .length;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedSection = section;
                          });
                        },
                        child: Text(
                          section,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.text,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (itemCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.2)
                                : AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$itemCount',
                            style: TextStyle(
                              fontSize: 9,
                              color: isSelected
                                  ? Colors.white70
                                  : AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _removeSection(section),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: isSelected
                              ? Colors.white70
                              : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeTab(String type, String label) {
    final isSelected = _itemType == type;
    BorderRadius borderRadius;
    if (type == Constants.itemTypeStock) {
      borderRadius = const BorderRadius.horizontal(left: Radius.circular(8));
    } else if (type == Constants.itemTypeOutsourced) {
      borderRadius = const BorderRadius.horizontal(right: Radius.circular(8));
    } else {
      borderRadius = BorderRadius.zero;
    }

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _itemType = type;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.white,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
            borderRadius: borderRadius,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primary : AppColors.textLight,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddItemsCard(ProductProvider productProvider) {
    return _buildCard(
      title: 'Add Items',
      icon: Icons.add_shopping_cart,
      iconColor: AppColors.secondary,
      tag: _items.isNotEmpty ? '${_items.length} items' : null,
      tagColor: AppColors.primary,
      child: Column(
        children: [
          if (_sections.isNotEmpty) ...[
            CustomDropdown<String>(
              value: _selectedSection.isEmpty ? null : _selectedSection,
              items: _sections.map((section) {
                final itemCount = _items
                    .where((item) => item.section == section)
                    .length;
                return DropdownMenuItem<String>(
                  value: section,
                  child: Row(
                    children: [
                      Expanded(child: Text(section)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$itemCount',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              label: 'Select Section (Optional)',
              isRequired: false,
              hint: 'Choose a section for items (Optional)',
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedSection = value;
                  });
                }
              },
              prefixIcon: const Icon(Icons.folder_open, size: 20),
            ),
            const SizedBox(height: 12),
          ],
          // Item Type Selection
          Row(
            children: [
              Text(
                'Item Type',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildTypeTab(Constants.itemTypeStock, 'Stock Item'),
              _buildTypeTab(Constants.itemTypeService, 'Labour'),
              _buildTypeTab(Constants.itemTypeOutsourced, 'Other'),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_itemType == Constants.itemTypeStock) ...[
            // Product Label & Search Field
            Row(
              children: [
                Text(
                  'Product *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _buildProductSearchWithCustomPrice(productProvider),
            const SizedBox(height: 12),
            
            // Further Description (Always visible below product search)
            CustomTextField(
              controller: _furtherDescriptionController,
              label: 'Further Description (optional)',
              hint: 'Add extra details, specifications, etc.',
              prefixIcon: const Icon(Icons.description, size: 18),
            ),
          ] else ...[
            // Custom item description
            CustomTextField(
              controller: _customDescriptionController,
              label: _itemType == Constants.itemTypeService ? 'Service / Labour Description *' : 'Item / Service Description *',
              hint: _itemType == Constants.itemTypeService ? 'e.g., General plumbing installation' : 'e.g., Miscellaneous service / supply',
              prefixIcon: Icon(
                _itemType == Constants.itemTypeService ? Icons.design_services : Icons.miscellaneous_services,
                size: 18,
              ),
            ),
            const SizedBox(height: 12),
            // Custom item unit price / fee
            CustomTextField(
              controller: _customUnitPriceController,
              label: _itemType == Constants.itemTypeService ? 'Labour Fee / Rate (KSh) *' : 'Cost (KSh) *',
              hint: '0.00',
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.attach_money, size: 18),
            ),
          ],
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _quantityController,
                  label: _itemType == Constants.itemTypeService ? 'Hours / Units' : 'Quantity',
                  keyboardType: TextInputType.number,
                  prefixIcon: const Icon(Icons.numbers, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomTextField(
                  controller: _discountController,
                  label: 'Discount (KSh or %)',
                  hint: '0 or 10%',
                  prefixIcon: const Icon(Icons.local_offer, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CustomButton(
            text: 'Add to Quote',
            onPressed: _addItem,
            icon: Icons.add,
            variant: ButtonVariant.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildProductSearchWithCustomPrice(ProductProvider productProvider) {
    if (productProvider.isLoading) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              TextField(
                controller: _productSearchController,
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: AppColors.textLight,
                  ),
                  suffixIcon: _productSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            size: 18,
                            color: AppColors.textLight,
                          ),
                          onPressed: () {
                            _productSearchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                child: _filteredProducts.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'No products found',
                            style: TextStyle(
                              color: AppColors.textLight,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          final isSelected = _selectedProduct?.id == product.id;
                          final isLowStock = product.isLowStock;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedProduct = product;
                                _productSearchController.text = product.name;
                                if (!_useCustomPrice) {
                                  _customPriceController.text = product
                                      .unitPrice
                                      .toString();
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : Colors.transparent,
                                border: Border(
                                  bottom: BorderSide(
                                    color: AppColors.border.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              '${product.category} • ${Formatters.currency(product.unitPrice)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textLight,
                                              ),
                                            ),
                                            if (isLowStock) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 1,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.warning
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Text(
                                                  'Low Stock',
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    color: AppColors.warning,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: AppColors.primary,
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
        ),
        const SizedBox(height: 8),
        if (_selectedProduct != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Custom Price',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: _useCustomPrice,
                      onChanged: (_) => _toggleCustomPrice(),
                      activeThumbColor: AppColors.primary,
                      activeTrackColor: AppColors.primary.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ],
                ),
                if (_useCustomPrice) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'System Price: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                      Text(
                        Formatters.currency(_selectedProduct!.unitPrice),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CustomTextField(
                          controller: _customPriceController,
                          label: '',
                          hint: 'Enter custom price',
                          keyboardType: TextInputType.number,
                          prefixIcon: Icon(
                            Icons.attach_money,
                            size: 18,
                            color: AppColors.textLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '💡 Enter a custom price for this item (optional)',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildItemsTable() {
    // Group items by section
    final Map<String, List<ExtendedQuoteItem>> groupedItems = {};
    for (final section in _sections) {
      groupedItems[section] = [];
    }
    for (final item in _items) {
      final section = item.section ?? 'General';
      groupedItems.putIfAbsent(section, () => []).add(item);
    }

    return _buildCard(
      title: 'Quote Items',
      icon: Icons.list_alt,
      iconColor: AppColors.primary,
      tag: '${_items.length} items',
      tagColor: AppColors.primary,
      child: Column(
        children: [
          // Table Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(flex: 1, child: _buildHeaderCell('#', center: true)),
                Expanded(flex: 4, child: _buildHeaderCell('Item')),
                Expanded(flex: 1, child: _buildHeaderCell('Qty', center: true)),
                Expanded(
                  flex: 2,
                  child: _buildHeaderCell('Price', center: true),
                ),
                Expanded(
                  flex: 2,
                  child: _buildHeaderCell('Discount', center: true),
                ),
                Expanded(
                  flex: 2,
                  child: _buildHeaderCell('Total', center: true),
                ),
                Expanded(flex: 1, child: _buildHeaderCell('', center: true)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // Grouped Items Table Body
          ...groupedItems.entries.expand((entry) {
            final sectionName = entry.key;
            final sectionItems = entry.value;
            final sectionTotal = sectionItems.fold(0.0, (sum, item) => sum + item.total);

            return [
              // Section Header row
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      sectionName.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'Subtotal: ${Formatters.currency(sectionTotal)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              if (sectionItems.isEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'No items in this section. Select this section in form above to add items.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),

              // Items in section
              ...sectionItems.asMap().entries.map((itemEntry) {
                final itemIndex = itemEntry.key + 1;
                final item = itemEntry.value;
                final globalIndex = _items.indexOf(item);

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: itemIndex.isEven ? Colors.white : AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: _buildCell(
                          itemIndex.toString(),
                          center: true,
                          color: AppColors.textLight,
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.description,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (item.isPriceEdited)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '✏️',
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                             const SizedBox(height: 2),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: _buildCell(
                          item.quantity.toString(),
                          center: true,
                          isBold: true,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildCell(
                          Formatters.currency(item.unitPrice),
                          center: true,
                          color: AppColors.textLight,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildCell(
                          item.discount > 0
                              ? '${Formatters.currency(item.discount)} (${item.discountPercentage.toStringAsFixed(0)}%)'
                              : 'KSh 0.00',
                          center: true,
                          color: AppColors.textLight,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildCell(
                          Formatters.currency(item.total),
                          center: true,
                          isBold: true,
                          color: AppColors.primary,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Center(
                          child: IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: AppColors.error,
                            ),
                            onPressed: () => _removeItem(globalIndex),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Remove item',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
            ];
          }),
        ],
      ),
    );
  }

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

  Widget _buildAdditionalInfoCard() {
    return _buildCard(
      title: 'Additional Information',
      icon: Icons.note_add,
      iconColor: AppColors.warning,
      tag: 'Optional',
      tagColor: AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDueDateField(),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _scopeController,
            label: 'Scope of Works / Service',
            hint: 'Describe the scope of works or service being done (optional)',
            maxLines: 3,
            prefixIcon: const Icon(Icons.work_outline, size: 20),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _notesController,
            label: 'Notes',
            hint: 'Add any notes (optional)',
            maxLines: 3,
            prefixIcon: const Icon(Icons.note_outlined, size: 20),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _termsController,
            label: 'Terms & Conditions (Optional)',
            hint: 'Type custom terms & conditions or leave blank to use system defaults',
            maxLines: 3,
            prefixIcon: const Icon(Icons.gavel, size: 20),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _siteMeasurementsController,
            label: 'Site Measurements',
            hint: 'Enter site measurements (optional)',
            maxLines: 2,
            prefixIcon: const Icon(Icons.straighten, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildDueDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.isInvoice ? 'Due Date (Optional)' : 'Valid Until / Due Date (Optional)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
            ),
            if (_dueDate != null)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _dueDate = null;
                  });
                },
                child: Text(
                  'Clear (No due date)',
                  style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 14)),
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              setState(() {
                _dueDate = picked;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _dueDate != null
                        ? DateFormat('EEE, MMM d, yyyy').format(_dueDate!)
                        : 'No due date set (Click to select date)',
                    style: TextStyle(
                      fontSize: 13,
                      color: _dueDate != null ? AppColors.text : AppColors.textLight,
                      fontWeight: _dueDate != null ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: AppColors.textLight),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.05),
            AppColors.primary.withValues(alpha: 0.01),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Apply Tax (16%)',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _applyTax ? 'Enabled' : 'Disabled',
                      style: TextStyle(
                        fontSize: 9,
                        color: _applyTax ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Switch(
                value: _applyTax,
                onChanged: _toggleTax,
                activeThumbColor: AppColors.primary,
                activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
              ),
            ],
          ),
          const Divider(),
          _buildTotalsRow('Subtotal', Formatters.currency(_subtotal)),
          const SizedBox(height: 4),
          if (_applyTax)
            _buildTotalsRow('Tax (16%)', Formatters.currency(_tax)),
          const Divider(height: 20),
          _buildTotalsRow(
            'Total',
            Formatters.currency(_total),
            isBold: true,
            isLarge: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsRow(
    String label,
    String value, {
    bool isBold = false,
    bool isLarge = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isLarge ? 18 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isLarge ? AppColors.text : AppColors.textLight,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 20 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isLarge ? AppColors.primary : AppColors.textLight,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopActionCard() {
    final bool canPreview = _selectedCustomer != null && _items.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ACTIONS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.textLight,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: _isSubmitting ? 'Saving...' : 'Save Quote',
                  onPressed: _isSubmitting ? null : _saveQuote,
                  icon: _isSubmitting ? null : Icons.save,
                  isLoading: _isSubmitting,
                  variant: ButtonVariant.primary,
                  size: ButtonSize.medium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Preview Quote',
                  onPressed: canPreview ? _previewQuote : null,
                  icon: Icons.visibility,
                  variant: ButtonVariant.secondary,
                  size: ButtonSize.medium,
                  isDisabled: !canPreview,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomButton(
                  text: 'Cancel',
                  onPressed: _showExitConfirmation,
                  isOutlined: true,
                  variant: ButtonVariant.outlined,
                  size: ButtonSize.medium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final bool canPreview = _selectedCustomer != null && _items.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: _isSubmitting
                      ? 'Saving...'
                      : (widget.isInvoice ? 'Save Invoice' : 'Save Quote'),
                  onPressed: _isSubmitting ? null : _saveQuote,
                  icon: _isSubmitting ? null : Icons.save,
                  isLoading: _isSubmitting,
                  variant: ButtonVariant.primary,
                  size: ButtonSize.medium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Preview',
                  onPressed: canPreview ? _previewQuote : null,
                  icon: Icons.visibility,
                  variant: ButtonVariant.secondary,
                  size: ButtonSize.medium,
                  isDisabled: !canPreview,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomButton(
                  text: 'Cancel',
                  onPressed: _showExitConfirmation,
                  isOutlined: true,
                  variant: ButtonVariant.outlined,
                  size: ButtonSize.medium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    String? tag,
    Color? tagColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (tag != null && tagColor != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tagColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: tagColor,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 20),
          child,
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
