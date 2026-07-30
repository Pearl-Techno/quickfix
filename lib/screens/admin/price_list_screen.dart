import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart' as pdf_core;
import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../config/app_colors.dart';
import '../../providers/product_provider.dart';
import '../../models/product.dart';
import '../../widgets/sidebar_menu.dart';
import '../../utils/formatters.dart';
import '../../utils/helpers.dart';
import '../../widgets/sync_refresh_button.dart';

// Extended Product model with bulk pricing
class ProductWithPricing extends Product {
  final double? bulkPrice;
  final int? bulkQuantity;
  final List<TieredPrice>? tieredPrices;

  ProductWithPricing({
    required super.id,
    required super.name,
    super.description,
    required super.category,
    super.subcategory,
    super.sku,
    super.barcode,
    required super.unitPrice,
    super.costPrice,
    required super.quantity,
    super.minStock,
    super.maxStock,
    super.unit,
    super.weight,
    super.width,
    super.height,
    super.length,
    super.brand,
    super.supplier,
    super.location,
    super.isActive,
    super.isTaxable,
    super.taxRate,
    super.imageUrl,
    super.notes,
    super.createdAt,
    super.updatedAt,
    this.bulkPrice,
    this.bulkQuantity = 10,
    this.tieredPrices,
  });

  factory ProductWithPricing.fromProduct(
    Product product, {
    double? bulkPrice,
    int? bulkQuantity,
    List<TieredPrice>? tieredPrices,
  }) {
    return ProductWithPricing(
      id: product.id,
      name: product.name,
      description: product.description,
      category: product.category,
      subcategory: product.subcategory,
      sku: product.sku,
      barcode: product.barcode,
      unitPrice: product.unitPrice,
      costPrice: product.costPrice,
      quantity: product.quantity,
      minStock: product.minStock,
      maxStock: product.maxStock,
      unit: product.unit,
      weight: product.weight,
      width: product.width,
      height: product.height,
      length: product.length,
      brand: product.brand,
      supplier: product.supplier,
      location: product.location,
      isActive: product.isActive,
      isTaxable: product.isTaxable,
      taxRate: product.taxRate,
      imageUrl: product.imageUrl,
      notes: product.notes,
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
      bulkPrice: bulkPrice ?? product.unitPrice * 0.85,
      bulkQuantity: bulkQuantity ?? 10,
      tieredPrices:
          tieredPrices ?? _generateDefaultTieredPrices(product.unitPrice),
    );
  }

  static List<TieredPrice> _generateDefaultTieredPrices(double unitPrice) {
    return [
      TieredPrice(minQty: 1, maxQty: 10, price: unitPrice),
      TieredPrice(minQty: 11, maxQty: 50, price: unitPrice * 0.9),
      TieredPrice(minQty: 51, maxQty: 100, price: unitPrice * 0.8),
      TieredPrice(minQty: 101, maxQty: null, price: unitPrice * 0.7),
    ];
  }

  double getPriceForQuantity(int qty) {
    if (tieredPrices != null) {
      for (var tier in tieredPrices!) {
        if (tier.isInRange(qty)) {
          return tier.price;
        }
      }
    }
    if (bulkPrice != null && qty >= (bulkQuantity ?? 10)) {
      return bulkPrice!;
    }
    return unitPrice;
  }

  double getTotalPriceForQuantity(int qty) {
    return getPriceForQuantity(qty) * qty;
  }

  double getSavingsPercentage(int qty) {
    final unitTotal = unitPrice * qty;
    final discountedTotal = getTotalPriceForQuantity(qty);
    if (unitTotal <= 0) return 0;
    return ((unitTotal - discountedTotal) / unitTotal) * 100;
  }
}

class TieredPrice {
  final int minQty;
  final int? maxQty;
  final double price;

  TieredPrice({required this.minQty, this.maxQty, required this.price});

  bool isInRange(int qty) {
    if (qty < minQty) return false;
    if (maxQty != null && qty > maxQty!) return false;
    return true;
  }

  String get displayRange {
    if (maxQty == null) {
      return '$minQty+';
    }
    return '$minQty - $maxQty';
  }
}

class PriceListScreen extends StatefulWidget {
  const PriceListScreen({super.key});

  @override
  State<PriceListScreen> createState() => _PriceListScreenState();
}

class _PriceListScreenState extends State<PriceListScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  List<ProductWithPricing> _allProducts = [];
  List<ProductWithPricing> _filteredProducts = [];
  bool _isLoading = false;
  bool _isExporting = false;
  int _selectedQuantity = 1;
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
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final productProvider = context.read<ProductProvider>();
    productProvider.clearAllFilters();
    await productProvider.loadProducts();

    final productsWithPricing = productProvider.products.map((product) {
      return ProductWithPricing.fromProduct(product);
    }).toList();

    _allProducts = productsWithPricing;
    _filterProducts();
    setState(() => _isLoading = false);
  }

  void _filterProducts() {
    final query = _searchController.text.trim().toLowerCase();
    var filtered = List<ProductWithPricing>.from(_allProducts);

    if (query.isNotEmpty) {
      filtered = filtered.where((product) {
        return product.name.toLowerCase().contains(query) ||
            product.category.toLowerCase().contains(query) ||
            (product.description?.toLowerCase().contains(query) ?? false) ||
            (product.sku?.toLowerCase().contains(query) ?? false) ||
            (product.brand?.toLowerCase().contains(query) ?? false) ||
            (product.supplier?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    if (_selectedCategory != 'All') {
      filtered = filtered
          .where((p) => p.category == _selectedCategory)
          .toList();
    }

    setState(() {
      _filteredProducts = filtered;
    });
  }


  // ============================================
  // PDF EXPORT METHODS
  // ============================================

  Future<void> _exportPriceListPDF() async {
    if (_filteredProducts.isEmpty) {
      Helpers.showError(context, 'No products to export');
      return;
    }

    setState(() => _isExporting = true);

    try {
      final pdf = await _generatePriceListPDF();
      final output = await getTemporaryDirectory();
      final file = File(
        '${output.path}/price_list_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(await pdf.save());

      setState(() => _isExporting = false);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PriceListPreviewPage(pdfFile: file),
        ),
      );
    } catch (e) {
      setState(() => _isExporting = false);
      if (mounted) {
        Helpers.showError(context, 'Failed to generate PDF: $e');
      }
    }
  }

  Future<pw.Document> _generatePriceListPDF() async {
    final pdf = pw.Document();
    final font = await _loadFont();

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData(
          defaultTextStyle: pw.TextStyle(font: font, fontSize: 10),
        ),
        build: (context) => [
          _buildPDFHeader(font),
          _buildPDFTitle(font),
          _buildPDFTable(font),
          _buildPDFFooter(font),
        ],
        footer: (context) => _buildPDFPageFooter(font),
      ),
    );

    return pdf;
  }

  Future<pw.Font> _loadFont() async {
    try {
      final fontData = await rootBundle.load(
        'assets/fonts/OpenSans-Regular.ttf',
      );
      return pw.Font.ttf(fontData.buffer.asByteData());
    } catch (e) {
      return pw.Font.helvetica();
    }
  }

  pw.Widget _buildPDFHeader(pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'QUICKFIX PLUMBERS',
            style: pw.TextStyle(
              font: font,
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: pdf_core.PdfColors.blue800,
            ),
          ),
          pw.Text(
            'Quality Plumbing Services',
            style: pw.TextStyle(
              font: font,
              fontSize: 12,
              color: pdf_core.PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Price List - ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
            style: pw.TextStyle(
              font: font,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (_selectedCategory != 'All')
            pw.Text(
              'Category: $_selectedCategory',
              style: pw.TextStyle(
                font: font,
                fontSize: 11,
                color: pdf_core.PdfColors.grey600,
              ),
            ),
          pw.Text(
            'Quantity: $_selectedQuantity units',
            style: pw.TextStyle(
              font: font,
              fontSize: 11,
              color: pdf_core.PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFTitle(pw.Font font) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: pdf_core.PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        'PRODUCT PRICE LIST',
        style: pw.TextStyle(
          font: font,
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: pdf_core.PdfColors.blue800,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildPDFTable(pw.Font font) {
    return pw.Table(
      border: pw.TableBorder.all(color: pdf_core.PdfColors.grey300),
      children: [
        // Table Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: pdf_core.PdfColors.blue50),
          children: [
            _buildPDFCell('#', font, isHeader: true, width: 30),
            _buildPDFCell('Product', font, isHeader: true, width: 150),
            _buildPDFCell('Category', font, isHeader: true, width: 80),
            _buildPDFCell(
              'Unit Price',
              font,
              isHeader: true,
              width: 80,
              align: pw.TextAlign.right,
            ),
            _buildPDFCell(
              'Bulk Price',
              font,
              isHeader: true,
              width: 80,
              align: pw.TextAlign.right,
            ),
            _buildPDFCell(
              'Qty',
              font,
              isHeader: true,
              width: 40,
              align: pw.TextAlign.center,
            ),
            _buildPDFCell(
              'Total',
              font,
              isHeader: true,
              width: 80,
              align: pw.TextAlign.right,
            ),
            _buildPDFCell(
              'Savings',
              font,
              isHeader: true,
              width: 60,
              align: pw.TextAlign.center,
            ),
          ],
        ),
        // Table Rows
        ..._filteredProducts.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final product = entry.value;
          final totalPrice = product.getTotalPriceForQuantity(
            _selectedQuantity,
          );
          final savings = product.getSavingsPercentage(_selectedQuantity);
          final isOutOfStock = product.isOutOfStock;

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isOutOfStock
                  ? pdf_core.PdfColors.red50
                  : index.isEven
                  ? pdf_core.PdfColors.grey50
                  : pdf_core.PdfColors.white,
            ),
            children: [
              _buildPDFCell(
                '$index',
                font,
                width: 30,
                align: pw.TextAlign.center,
              ),
              _buildPDFCell(product.name, font, width: 150, isBold: true),
              _buildPDFCell(product.category, font, width: 80),
              _buildPDFCell(
                'KSh ${product.unitPrice.toStringAsFixed(2)}',
                font,
                width: 80,
                align: pw.TextAlign.right,
              ),
              _buildPDFCell(
                product.bulkPrice != null
                    ? 'KSh ${product.bulkPrice!.toStringAsFixed(2)}'
                    : 'N/A',
                font,
                width: 80,
                align: pw.TextAlign.right,
              ),
              _buildPDFCell(
                '$_selectedQuantity',
                font,
                width: 40,
                align: pw.TextAlign.center,
              ),
              _buildPDFCell(
                'KSh ${totalPrice.toStringAsFixed(2)}',
                font,
                width: 80,
                align: pw.TextAlign.right,
                isBold: true,
              ),
              _buildPDFCell(
                savings > 0 ? '${savings.toStringAsFixed(0)}%' : '0%',
                font,
                width: 60,
                align: pw.TextAlign.center,
              ),
            ],
          );
        }),
        // Total Row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: pdf_core.PdfColors.blue50),
          children: [
            _buildPDFCell('', font, width: 30),
            _buildPDFCell(
              'TOTAL PRODUCTS: ${_filteredProducts.length}',
              font,
              width: 150,
              isBold: true,
              color: pdf_core.PdfColors.blue800,
            ),
            _buildPDFCell('', font, width: 80),
            _buildPDFCell('', font, width: 80),
            _buildPDFCell('', font, width: 80),
            _buildPDFCell('', font, width: 40),
            _buildPDFCell(
              'KSh ${_filteredProducts.fold(0.0, (sum, p) => sum + p.getTotalPriceForQuantity(_selectedQuantity)).toStringAsFixed(2)}',
              font,
              width: 80,
              align: pw.TextAlign.right,
              isBold: true,
              color: pdf_core.PdfColors.blue800,
            ),
            _buildPDFCell('', font, width: 60),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPDFCell(
    String text,
    pw.Font font, {
    double width = 0,
    bool isHeader = false,
    bool isBold = false,
    pw.PdfColor? color,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.SizedBox(
      width: width > 0 ? width : null,
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            font: font,
            fontSize: isHeader ? 10 : 9,
            fontWeight: isHeader || isBold
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
            color:
                color ??
                (isHeader
                    ? pdf_core.PdfColors.blue800
                    : pdf_core.PdfColors.black),
          ),
          textAlign: align,
        ),
      ),
    );
  }

  pw.Widget _buildPDFFooter(pw.Font font) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 16),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: pdf_core.PdfColors.grey300),
        ),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'Thank you for choosing Quickfix Plumbers',
            style: pw.TextStyle(
              font: font,
              fontSize: 10,
              color: pdf_core.PdfColors.grey700,
              fontStyle: pw.FontStyle.italic,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Contact: 0702 687 799 | Email: quickfix@gmail.com',
            style: pw.TextStyle(
              font: font,
              fontSize: 8,
              color: pdf_core.PdfColors.grey500,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFPageFooter(pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Generated on ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
        style: pw.TextStyle(
          font: font,
          fontSize: 7,
          color: pdf_core.PdfColors.grey400,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final categories = ['All', ...productProvider.getCategories()];

    // Calculate stats
    final totalProducts = productProvider.products.length;
    final lowStock = productProvider.products.where((p) => p.isLowStock).length;
    final outOfStock = productProvider.products
        .where((p) => p.isOutOfStock)
        .length;
    final totalValue = _filteredProducts.fold(
      0.0,
      (sum, p) => sum + p.getTotalPriceForQuantity(_selectedQuantity),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Price List',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          Row(
            children: [
              const Text(
                'Qty: ',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              DropdownButton<int>(
                value: _selectedQuantity,
                dropdownColor: Colors.white,
                style: const TextStyle(color: Colors.white),
                underline: Container(),
                items: [1, 5, 10, 25, 50, 100].map((value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(
                      '$value',
                      style: const TextStyle(color: Colors.black),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedQuantity = value);
                  }
                },
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf),
            onPressed: _isExporting ? null : _exportPriceListPDF,
            tooltip: 'Export PDF',
          ),
          const SyncRefreshButton(color: Colors.white),
        ],
      ),
      drawer: const SidebarMenu(
        selectedIndex: 10,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildSearchAndFilterBar(categories),
            _buildStatsBar(
              totalProducts: totalProducts,
              filteredCount: _filteredProducts.length,
              lowStock: lowStock,
              outOfStock: outOfStock,
              totalValue: totalValue,
            ),
            Expanded(
              child: _isLoading || productProvider.isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Loading products...',
                            style: TextStyle(color: AppColors.textLight),
                          ),
                        ],
                      ),
                    )
                  : _filteredProducts.isEmpty
                  ? _buildEmptyState()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final availableW = constraints.maxWidth - 32;
                        final tableW = availableW > 1000 ? availableW : 1000.0;
                        return RefreshIndicator(
                          onRefresh: _loadData,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: tableW,
                                child: _buildProductTable(),
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

  Widget _buildSearchAndFilterBar(List<String> categories) {
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
                  onChanged: (value) => _filterProducts(),
                  decoration: InputDecoration(
                    hintText: 'Search products...',
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
                              _filterProducts();
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
                onTap: () => _filterProducts(),
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
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = category == _selectedCategory;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                    _filterProducts();
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
                          category,
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
    required int totalProducts,
    required int filteredCount,
    required int lowStock,
    required int outOfStock,
    required double totalValue,
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
                  '$filteredCount / $totalProducts',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (lowStock > 0)
                _buildStatChip('$lowStock low stock', AppColors.warning),
              if (outOfStock > 0)
                _buildStatChip('$outOfStock out of stock', AppColors.error),
            ],
          ),
          Row(
            children: [
              Text(
                'Total: ',
                style: TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
              Text(
                Formatters.currency(totalValue),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              if (_searchController.text.isNotEmpty ||
                  _selectedCategory != 'All')
                const SizedBox(width: 12),
              if (_searchController.text.isNotEmpty ||
                  _selectedCategory != 'All')
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = 'All';
                      _searchController.clear();
                    });
                    _filterProducts();
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
  // PRODUCT TABLE (FULL WIDTH - UPDATED)
  // ============================================

  Widget _buildProductTable() {
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
              Expanded(flex: 3, child: _buildHeaderCell('Product Name')),
              Expanded(flex: 2, child: _buildHeaderCell('Category')),
              Expanded(
                flex: 2,
                child: _buildHeaderCell('Unit Price', center: true),
              ),
              Expanded(
                flex: 2,
                child: _buildHeaderCell('Bulk Price', center: true),
              ),
              Expanded(flex: 1, child: _buildHeaderCell('Qty', center: true)),
              Expanded(flex: 2, child: _buildHeaderCell('Total', center: true)),
              Expanded(
                flex: 1,
                child: _buildHeaderCell('Savings', center: true),
              ),
              Expanded(
                flex: 2,
                child: _buildHeaderCell('Status', center: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Table Body
        ..._filteredProducts.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final product = entry.value;
          final isLowStock = product.isLowStock;
          final isOutOfStock = product.isOutOfStock;
          final totalPrice = product.getTotalPriceForQuantity(
            _selectedQuantity,
          );
          final savings = product.getSavingsPercentage(_selectedQuantity);

          return InkWell(
            onTap: () => _showProductDetails(product),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isOutOfStock
                    ? AppColors.error.withValues(alpha: 0.05)
                    : isLowStock
                    ? AppColors.warning.withValues(alpha: 0.05)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: isLowStock || isOutOfStock
                    ? Border.all(
                        color: isOutOfStock
                            ? AppColors.error
                            : AppColors.warning,
                        width: 1,
                      )
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
                  // Index
                  Expanded(
                    flex: 1,
                    child: _buildCell(
                      index.toString(),
                      center: true,
                      color: AppColors.textLight,
                    ),
                  ),
                  // Product Name
                  Expanded(
                    flex: 3,
                    child: _buildCell(product.name, isBold: true),
                  ),
                  // Category
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        product.category,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.info,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  // Unit Price
                  Expanded(
                    flex: 2,
                    child: _buildCell(
                      Formatters.currency(product.unitPrice),
                      center: true,
                      isBold: true,
                      color: AppColors.primary,
                    ),
                  ),
                  // Bulk Price
                  Expanded(
                    flex: 2,
                    child: _buildCell(
                      product.bulkPrice != null
                          ? Formatters.currency(product.bulkPrice!)
                          : 'N/A',
                      center: true,
                      isBold: true,
                      color: AppColors.secondary,
                    ),
                  ),
                  // Quantity
                  Expanded(
                    flex: 1,
                    child: _buildCell(
                      _selectedQuantity.toString(),
                      center: true,
                      color: AppColors.text,
                    ),
                  ),
                  // Total
                  Expanded(
                    flex: 2,
                    child: _buildCell(
                      Formatters.currency(totalPrice),
                      center: true,
                      isBold: true,
                      color: AppColors.primary,
                    ),
                  ),
                  // Savings
                  Expanded(
                    flex: 1,
                    child: _buildCell(
                      savings > 0 ? '${savings.toStringAsFixed(0)}%' : '0%',
                      center: true,
                      isBold: savings > 0,
                      color: savings > 0
                          ? AppColors.success
                          : AppColors.textLight,
                    ),
                  ),
                  // Status
                  Expanded(flex: 2, child: _buildStatusCell(product)),
                ],
              ),
            ),
          );
        }),
        // Pricing Legend
        const SizedBox(height: 12),
        _buildPricingLegend(),
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

  Widget _buildStatusCell(ProductWithPricing product) {
    final isLowStock = product.isLowStock;
    final isOutOfStock = product.isOutOfStock;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (isOutOfStock) {
      statusColor = AppColors.error;
      statusText = 'Out of Stock';
      statusIcon = Icons.cancel;
    } else if (isLowStock) {
      statusColor = AppColors.warning;
      statusText = 'Low Stock';
      statusIcon = Icons.warning;
    } else {
      statusColor = AppColors.success;
      statusText = 'In Stock';
      statusIcon = Icons.check_circle;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                statusText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================
  // PRICING LEGEND
  // ============================================

  Widget _buildPricingLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💡 Pricing Legend',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildLegendItem('Unit Price', AppColors.primary),
              const SizedBox(width: 16),
              _buildLegendItem('Bulk Price', AppColors.secondary),
              const SizedBox(width: 16),
              _buildLegendItem('Savings', AppColors.success),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '• Adjust quantity above to see volume discounts',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textLight,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 16, height: 3, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textLight)),
      ],
    );
  }

  // ============================================
  // EMPTY STATE
  // ============================================

  Widget _buildEmptyState() {
    final hasFilters =
        _searchController.text.isNotEmpty || _selectedCategory != 'All';

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
              hasFilters ? Icons.search_off : Icons.inventory_2_outlined,
              size: 48,
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'No matching products' : 'No products yet',
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
                : 'Add products to your inventory',
            style: TextStyle(fontSize: 14, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  // ============================================
  // PRODUCT DETAILS
  // ============================================

  void _showProductDetails(ProductWithPricing product) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(product.category),
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        product.category,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textLight,
                        ),
                      ),
                      if (product.brand != null)
                        Text(
                          'Brand: ${product.brand}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _buildDetailRow('Description', product.description ?? 'N/A'),
            _buildDetailRow(
              'Unit Price',
              Formatters.currency(product.unitPrice),
            ),
            if (product.bulkPrice != null)
              _buildDetailRow(
                'Bulk Price',
                Formatters.currency(product.bulkPrice!),
              ),
            _buildDetailRow('Stock Quantity', product.quantity.toString()),
            _buildDetailRow(
              'Price for $_selectedQuantity units',
              Formatters.currency(
                product.getTotalPriceForQuantity(_selectedQuantity),
              ),
            ),
            const SizedBox(height: 12),
            if (product.tieredPrices != null) ...[
              const Text(
                'Volume Discounts',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: product.tieredPrices!.map((tier) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${tier.displayRange} units',
                            style: const TextStyle(fontSize: 13),
                          ),
                          Text(
                            Formatters.currency(tier.price),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'pipes':
        return Icons.grain;
      case 'fittings':
        return Icons.settings_ethernet;
      case 'valves':
        return Icons.settings_overscan;
      case 'meters':
        return Icons.speed;
      case 'tools':
        return Icons.build;
      case 'accessories':
        return Icons.bolt;
      default:
        return Icons.inventory_2;
    }
  }
}

// ============================================
// PRICE LIST PREVIEW PAGE
// ============================================

class PriceListPreviewPage extends StatefulWidget {
  final File pdfFile;

  const PriceListPreviewPage({super.key, required this.pdfFile});

  @override
  State<PriceListPreviewPage> createState() => _PriceListPreviewPageState();
}

class _PriceListPreviewPageState extends State<PriceListPreviewPage> {
  bool _isPrinting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Price List Preview'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _isPrinting ? null : _downloadPDF,
            tooltip: 'Download',
          ),
          IconButton(
            icon: _isPrinting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.print),
            onPressed: _isPrinting ? null : _printPDF,
            tooltip: 'Print',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _isPrinting ? null : _sharePDF,
            tooltip: 'Share',
          ),
        ],
      ),
      body: PdfPreview(
        build: (context) => widget.pdfFile.readAsBytesSync(),
        allowPrinting: false,
        allowSharing: false,
        maxPageWidth: 700,
        scrollViewDecoration: const BoxDecoration(color: AppColors.background),
        onError: (error, _) {
          if (mounted) {
            Helpers.showError(context, 'Failed to load PDF: $error');
          }
          return const SizedBox.shrink();
        },
        loadingWidget: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading preview...',
                style: TextStyle(color: AppColors.textLight),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _printPDF() async {
    setState(() => _isPrinting = true);

    try {
      await Printing.layoutPdf(
        onLayout: (format) => widget.pdfFile.readAsBytesSync(),
        name: 'price_list.pdf',
      );
    } catch (e) {
      if (mounted) {
        Helpers.showError(context, 'Failed to print: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  Future<void> _sharePDF() async {
    try {
      final bytes = await widget.pdfFile.readAsBytes();
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/price_list.pdf');
      await tempFile.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          text: 'Price List - Quickfix Plumbers',
        ),
      );
    } catch (e) {
      if (mounted) {
        Helpers.showError(context, 'Failed to share: $e');
      }
    }
  }

  Future<void> _downloadPDF() async {
    setState(() => _isPrinting = true);
    try {
      final file = await Helpers.downloadPdfToLocalDisk(widget.pdfFile, 'receipt');
      if (file == null) throw Exception('Failed to write file to local disk');
      if (mounted) {
        Helpers.showSuccess(context, 'Saved to: ${file.path}');
      }
    } catch (e) {
      if (mounted) {
        Helpers.showError(context, 'Failed to download: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }
}
