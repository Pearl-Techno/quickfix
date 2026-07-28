import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_colors.dart';
import '../../config/constants.dart';
import '../../providers/customer_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/quote_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../models/quote_item.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/image_picker_widget.dart';
import '../../widgets/sidebar_menu.dart';
import '../../widgets/quote_preview_dialog.dart';
import '../../utils/helpers.dart';
import '../../utils/formatters.dart';

class CreateSiteQuote extends StatefulWidget {
  const CreateSiteQuote({super.key});

  @override
  State<CreateSiteQuote> createState() => _CreateSiteQuoteState();
}

class _CreateSiteQuoteState extends State<CreateSiteQuote>
    with SingleTickerProviderStateMixin {
  final _notesController = TextEditingController();
  final _siteMeasurementsController = TextEditingController();
  final _productSearchController = TextEditingController();
  final _furtherDescriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _customDescriptionController = TextEditingController();
  final _customUnitPriceController = TextEditingController();
  final _sectionNameController = TextEditingController();

  bool _useDirectClient = false;
  final _directClientNameController = TextEditingController();
  final _directClientPhoneController = TextEditingController();
  final _directClientEmailController = TextEditingController();
  final _directClientAddressController = TextEditingController();
  final _directClientSiteLocationController = TextEditingController();
  final _scopeController = TextEditingController();

  Customer? _selectedCustomer;
  Product? _selectedProduct;
  String _itemType = Constants.itemTypeStock;
  List<Product> _filteredProducts = [];
  String _selectedSection = 'Materials';

  final List<QuoteItem> _items = [];
  final List<String> _sections = ['Materials', 'Labour', 'Transport'];
  final List<XFile> _photos = [];
  double _subtotal = 0;
  double _tax = 0;
  double _total = 0;

  bool _isSubmitting = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _productSearchController.addListener(_filterProducts);
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
  }

  @override
  void dispose() {
    _productSearchController.removeListener(_filterProducts);
    _productSearchController.dispose();
    _notesController.dispose();
    _siteMeasurementsController.dispose();
    _furtherDescriptionController.dispose();
    _customDescriptionController.dispose();
    _customUnitPriceController.dispose();
    _sectionNameController.dispose();
    _directClientNameController.dispose();
    _directClientPhoneController.dispose();
    _directClientEmailController.dispose();
    _directClientAddressController.dispose();
    _directClientSiteLocationController.dispose();
    _scopeController.dispose();
    _quantityController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final customerProvider = context.read<CustomerProvider>();
    customerProvider.clearSearch();
    final productProvider = context.read<ProductProvider>();
    productProvider.clearAllFilters();
    await Future.wait([
      customerProvider.loadCustomers(),
      productProvider.loadProducts(),
    ]);
    if (!mounted) return;
    _filterProducts();
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

  void _addItem() {
    if (_selectedCustomer == null && !_useDirectClient) {
      Helpers.showError(context, 'Please select a customer first');
      return;
    }

    if (_selectedSection.isEmpty && _sections.isNotEmpty) {
      Helpers.showError(context, 'Please select a section');
      return;
    }

    if (_selectedProduct == null && _itemType == Constants.itemTypeStock) {
      Helpers.showError(context, 'Please select a product');
      return;
    }

    String description = '';
    double unitPrice = 0;

    if (_itemType == Constants.itemTypeStock && _selectedProduct != null) {
      description = _selectedProduct!.name;
      final furtherDesc = _furtherDescriptionController.text.trim();
      if (furtherDesc.isNotEmpty) {
        description += ' - $furtherDesc';
      }
      unitPrice = _selectedProduct!.unitPrice;
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
    }

    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;

    final item = QuoteItem(
      id: Helpers.generateId(),
      quoteId: '',
      productId: _itemType == Constants.itemTypeStock ? _selectedProduct?.id : null,
      itemType: _itemType,
      description: description,
      quantity: quantity,
      unitPrice: unitPrice,
      total: unitPrice * quantity,
      section: _selectedSection,
    );

    setState(() {
      _items.add(item);
      _calculateTotals();
      _selectedProduct = null;
      _quantityController.text = '1';
      _productSearchController.clear();
      _furtherDescriptionController.clear();
      _customDescriptionController.clear();
      _customUnitPriceController.clear();
    });

    Helpers.showSuccess(context, 'Item added to $_selectedSection');
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _calculateTotals();
    });
  }

  void _calculateTotals() {
    _subtotal = _items.fold(0.0, (sum, item) => sum + item.total);
    _tax = _subtotal * Constants.taxRate;
    _total = _subtotal + _tax;
  }

  Future<void> _uploadPhotos(String quoteId) async {
    if (_photos.isEmpty) return;

    final storageService = StorageService();
    int uploadedCount = 0;

    for (var photo in _photos) {
      try {
        final url = await storageService.uploadPhoto(
          image: photo,
          quoteId: quoteId,
          description: 'Site photo',
        );
        if (url != null) {
          uploadedCount++;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to upload photo: $e');
        }
      }
    }

    if (mounted && uploadedCount > 0) {
      Helpers.showSnackBar(
        context,
        '$uploadedCount photo(s) uploaded',
        backgroundColor: AppColors.success,
      );
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

    final currentUser = context.read<AuthProvider>().currentUser;
    final userId = currentUser?.id ?? '';
    final items = List<QuoteItem>.from(_items);
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();
    final siteMeasurements = _siteMeasurementsController.text.trim().isEmpty
        ? null
        : _siteMeasurementsController.text.trim();
    final scope = _scopeController.text.trim().isEmpty
        ? null
        : _scopeController.text.trim();

    final customerProvider = context.read<CustomerProvider>();
    final quoteProvider = context.read<QuoteProvider>();

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
        if (targetCustomer == null) {
          throw Exception(customerProvider.errorMessage ?? 'Failed to create customer');
        }
      } catch (e) {
        setState(() => _isSubmitting = false);
        if (mounted) {
          Helpers.showError(context, 'Failed to create direct client: $e');
        }
        return;
      }
    }

    final quote = await quoteProvider.createQuote(
      customerId: targetCustomer!.id,
      userId: userId,
      items: items,
      scope: scope,
      notes: notes,
      siteMeasurements: siteMeasurements,
    );

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (quote != null) {
      if (_photos.isNotEmpty) {
        await _uploadPhotos(quote.id);
      }

      if (!mounted) return;

      Helpers.showSuccess(context, 'Site quote created successfully');
      Navigator.pop(context, true);
    } else {
      Helpers.showError(
        context,
        quoteProvider.errorMessage ?? 'Failed to create quote',
      );
    }
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
      'applyTax': true,
    };

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => QuotePreviewDialog(quoteData: quoteData),
    );

    if (result == true) {
      _saveQuote();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Site Quote'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility),
            onPressed: _previewQuote,
            tooltip: 'Preview Quote',
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 80),
            child: TextButton(
              onPressed: _isSubmitting ? null : _saveQuote,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
      drawer: const SidebarMenu(
        selectedIndex: 5,
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
                          _buildCustomerCard(),
                          const SizedBox(height: 16),
                          _buildSectionsCard(),
                          const SizedBox(height: 16),
                          _buildAddItemsCard(),
                          if (_items.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildItemsCard(),
                          ],
                          const SizedBox(height: 16),
                          _buildPhotosCard(),
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
                          _buildMeasurementsCard(),
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
                    _buildCustomerCard(),
                    const SizedBox(height: 16),
                    _buildSectionsCard(),
                    const SizedBox(height: 16),
                    _buildAddItemsCard(),
                    if (_items.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildItemsCard(),
                    ],
                    const SizedBox(height: 16),
                    _buildPhotosCard(),
                    const SizedBox(height: 16),
                    _buildMeasurementsCard(),
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
              Icons.location_on,
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
                  'Site Visit',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Create a quote on-site with photos and measurements',
                  style: TextStyle(fontSize: 13, color: AppColors.textLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard() {
    final customerProvider = context.watch<CustomerProvider>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Customer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Required',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
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
                          fontSize: 11,
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
                          fontSize: 11,
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
                  child: Text(customer.name),
                );
              }).toList(),
              label: 'Select Customer',
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
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/admin/customers/add');
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Add New Customer'),
                  ),
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

  Widget _buildSectionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.folder,
                  size: 18,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Sections / Categories',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_sections.length} sections',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.info,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _sectionNameController,
                  label: 'Section Name',
                  hint: 'e.g., Kitchen, Bathroom, Plumbing',
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

  Widget _buildAddItemsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.add_shopping_cart,
                  size: 18,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Add Items',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (_items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_items.length} items',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 20),
          if (_sections.isNotEmpty) ...[
            CustomDropdown<String>(
              value: _selectedSection,
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
              label: 'Select Section *',
              hint: 'Choose a section for items',
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
              _buildTypeTab(Constants.itemTypeOutsourced, 'Transport / Other'),
            ],
          ),
          const SizedBox(height: 16),

          if (_itemType == Constants.itemTypeStock) ...[
            // Product Search
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Product *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
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
                          suffixIcon:
                              _productSearchController.text.isNotEmpty
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
                        constraints: const BoxConstraints(
                          maxHeight: 150,
                        ),
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
                                physics:
                                    const ClampingScrollPhysics(),
                                itemCount: _filteredProducts.length,
                                itemBuilder: (context, index) {
                                  final product =
                                      _filteredProducts[index];
                                  final isSelected =
                                      _selectedProduct?.id ==
                                      product.id;
                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedProduct = product;
                                        _productSearchController
                                                .text =
                                            product.name;
                                      });
                                    },
                                    child: Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary
                                                  .withValues(
                                                    alpha: 0.1,
                                                  )
                                            : Colors.transparent,
                                        border: Border(
                                          bottom: BorderSide(
                                            color: AppColors.border
                                                .withValues(
                                                  alpha: 0.3,
                                                ),
                                          ),
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
              ],
            ),
            const SizedBox(height: 12),
            
            // Further Description (Always visible below product search)
            CustomTextField(
              controller: _furtherDescriptionController,
              label: 'Further Description (optional)',
              hint: 'Add extra details, specifications, etc.',
              prefixIcon: const Icon(Icons.description, size: 20),
            ),
          ] else ...[
            // Custom item description
            CustomTextField(
              controller: _customDescriptionController,
              label: _itemType == Constants.itemTypeService ? 'Service / Labour Description *' : 'Transport / Item Description *',
              hint: _itemType == Constants.itemTypeService ? 'e.g., General plumbing installation' : 'e.g., Transport to site',
              prefixIcon: Icon(
                _itemType == Constants.itemTypeService ? Icons.design_services : Icons.local_shipping,
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

          // Quantity & Add Row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: CustomTextField(
                  controller: _quantityController,
                  label: _itemType == Constants.itemTypeService ? 'Hours / Units' : 'Quantity',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: CustomButton(
                  text: 'Add to Quote',
                  onPressed: _addItem,
                  icon: Icons.add,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
    // Group items by section
    final Map<String, List<QuoteItem>> groupedItems = {};
    for (final section in _sections) {
      groupedItems[section] = [];
    }
    for (final item in _items) {
      final section = item.section ?? 'General';
      groupedItems.putIfAbsent(section, () => []).add(item);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quote Items',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Text(
                'Total: ${Formatters.currency(_subtotal)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No items added yet',
                  style: TextStyle(color: AppColors.textLight),
                ),
              ),
            )
          else
            ...groupedItems.entries.map((entry) {
              final sectionName = entry.key;
              final sectionItems = entry.value;
              final sectionTotal = sectionItems.fold(0.0, (sum, item) => sum + item.total);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  const SizedBox(height: 6),
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
                    )
                  else
                    ...sectionItems.asMap().entries.map((itemEntry) {
                    final itemIdx = itemEntry.key + 1;
                    final item = itemEntry.value;
                    final globalIndex = _items.indexOf(item);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            child: Text(
                              '$itemIdx',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.description,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '${item.quantity} × ${Formatters.currency(item.unitPrice)}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Text(
                            Formatters.currency(item.total),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.error,
                            ),
                            onPressed: () => _removeItem(globalIndex),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPhotosCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.photo_camera,
                  size: 18,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Site Photos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Optional',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.info,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ImagePickerWidget(
            onImagesSelected: (images) {
              setState(() {
                _photos.clear();
                _photos.addAll(images);
              });
            },
            maxImages: 5,
            label: 'Add Site Photos',
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.straighten,
                  size: 18,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Scope & Measurements',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Optional',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          CustomTextField(
            controller: _scopeController,
            label: 'Scope of Works / Service',
            hint: 'Describe the scope of works or service being done (optional)',
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: _siteMeasurementsController,
            label: 'Measurements',
            hint: 'Enter dimensions, conditions, etc.',
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: _notesController,
            label: 'Notes',
            hint: 'Add any site notes (optional)',
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildTotalsRow('Subtotal', Formatters.currency(_subtotal)),
          const SizedBox(height: 4),
          _buildTotalsRow(
            'Tax (${(Constants.taxRate * 100).toInt()}%)',
            Formatters.currency(_tax),
          ),
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

  Widget _buildDesktopActionCard() {
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
                  text: _isSubmitting ? 'Creating...' : 'Create Site Quote',
                  onPressed: _isSubmitting ? null : _saveQuote,
                  icon: _isSubmitting ? null : Icons.save,
                  isLoading: _isSubmitting,
                  size: ButtonSize.medium,
                  variant: ButtonVariant.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Cancel',
                  onPressed: () => Navigator.pop(context),
                  isOutlined: true,
                  size: ButtonSize.medium,
                  variant: ButtonVariant.outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
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
                  text: _isSubmitting ? 'Creating Quote...' : 'Create Site Quote',
                  onPressed: _isSubmitting ? null : _saveQuote,
                  icon: _isSubmitting ? null : Icons.save,
                  isLoading: _isSubmitting,
                  size: ButtonSize.medium,
                  variant: ButtonVariant.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Cancel',
                  onPressed: () => Navigator.pop(context),
                  isOutlined: true,
                  size: ButtonSize.medium,
                  variant: ButtonVariant.outlined,
                ),
              ),
            ],
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
