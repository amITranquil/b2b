// lib/screens/quote_form_screen.dart
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/quote.dart';
import '../services/api_service.dart';
import '../services/pdf_export_service.dart';
import '../core/di/service_locator.dart';
import '../core/error/error_handler.dart';
import '../widgets/decimal_input_field.dart';
import 'manual_product_form_screen.dart';

class QuoteFormScreen extends StatefulWidget {
  final List<QuoteItem>? initialItems;
  final Quote? existingQuote; // Düzenleme için mevcut teklif

  const QuoteFormScreen({
    super.key,
    this.initialItems,
    this.existingQuote,
  });

  @override
  QuoteFormScreenState createState() => QuoteFormScreenState();
}

class QuoteFormScreenState extends State<QuoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final _serviceLocator = ServiceLocator();
  final numberFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
  final pdfExportService = PdfExportService();

  List<QuoteItem> quoteItems = [];
  List<Product> availableProducts = [];
  bool _isLoading = false;

  // Form controller'ları
  final _customerNameController = TextEditingController();
  final _customerRepController = TextEditingController();
  final _phoneController = TextEditingController();
  final _paymentTermController = TextEditingController();
  final _noteController = TextEditingController();
  final _extraNoteController =
      TextEditingController(); // Ek not için controller

  // Manuel ürün ekleme controller'ları
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _marginController = TextEditingController(text: '40');
  String _selectedUnit = 'adet';
  double _selectedVatRate = 20; // Default KDV %20

  // Ürün satırı düzenleme controller'ları
  final Map<int, TextEditingController> _itemDescriptionControllers = {};
  final Map<int, TextEditingController> _itemQuantityControllers = {};
  final Map<int, TextEditingController> _itemPriceControllers = {};
  final Map<int, TextEditingController> _itemMarginControllers = {};
  final Map<int, String> _itemUnitValues = {};
  final Map<int, bool> _itemEditModes = {};

  // Silinen öğeleri izlemek için
  final Set<String> _deletedItemIds = {};

  // Ürün arama için
  final _productSearchController = TextEditingController();
  String _productSearchQuery = '';

  // Unit dropdown options (DRY)
  static const List<String> unitOptions = [
    'adet',
    'metre',
    'kg',
    'litre',
    'kutu',
    'paket'
  ];

  // ========== HELPER METHODS (DRY) ==========

  /// Loading state helper
  void _setLoading(bool loading) {
    if (mounted) {
      setState(() => _isLoading = loading);
    }
  }

  /// Success message helper
  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Error message helper
  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Info message helper
  void _showInfoMessage(String message, {Color? backgroundColor}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor ?? Colors.blue,
        ),
      );
    }
  }

  /// Active items filtering helper
  List<QuoteItem> _getActiveItems() {
    return quoteItems
        .where((item) => item.id.isEmpty || !_deletedItemIds.contains(item.id))
        .toList();
  }

  @override
  void initState() {
    super.initState();

    // Eğer existingQuote varsa VE ID geçerliyse, backend'den güncel hali ile yükle
    if (widget.existingQuote != null && widget.existingQuote!.id != '0') {
      _loadQuoteFromBackend();
      // _initItemControllers() _loadExistingQuote() içinde çağrılacak
    } else if (widget.existingQuote != null) {
      // ID 0 ise (yeni kayıt), direkt yükle
      _loadExistingQuote(widget.existingQuote!);
    } else if (widget.initialItems != null) {
      // Deep copy of initialItems to prevent reference issues
      quoteItems = widget.initialItems!
          .map((item) => QuoteItem(
                id: item.id,
                quoteId: item.quoteId,
                description: item.description,
                quantity: item.quantity,
                unit: item.unit,
                price: item.price,
                vatRate: item.vatRate,
              ))
          .toList();
      _initItemControllers();
    }

    _loadProducts();
  }

  void _initItemControllers() {
    _itemDescriptionControllers.clear();
    _itemQuantityControllers.clear();
    _itemPriceControllers.clear();
    _itemMarginControllers.clear();
    _itemUnitValues.clear();
    _itemEditModes.clear();

    for (int i = 0; i < quoteItems.length; i++) {
      _itemDescriptionControllers[i] =
          TextEditingController(text: quoteItems[i].description);
      _itemQuantityControllers[i] =
          TextEditingController(text: quoteItems[i].quantity.toString());
      _itemPriceControllers[i] =
          TextEditingController(text: quoteItems[i].price.toString());
      _itemMarginControllers[i] =
          TextEditingController(text: quoteItems[i].marginPercentage.toString());
      _itemUnitValues[i] = quoteItems[i].unit;
      _itemEditModes[i] = false;
    }
  }

  Future<void> _loadQuoteFromBackend() async {
    try {
      _setLoading(true);
      final quote = await _apiService.getQuote(widget.existingQuote!.id);
      if (mounted) {
        _loadExistingQuote(quote);
        _setLoading(false);
      }
    } catch (e) {
      _setLoading(false);
      _showErrorMessage('Teklif yüklenirken hata: $e');
    }
  }

  Future<void> _loadProducts() async {
    try {
      _setLoading(true);
      availableProducts = await _apiService.getProducts();
      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      _showErrorMessage('Ürünler yüklenirken hata: $e');
    }
  }

  void _loadExistingQuote(Quote quote) {
    _customerNameController.text = quote.customerName;
    _customerRepController.text = quote.representative;
    _phoneController.text = quote.phone;
    _paymentTermController.text = quote.paymentTerm;
    _noteController.text = quote.note;

    // ExtraNote alanını yükle (null check ile)
    if (quote.extraNote != null) {
      _extraNoteController.text = quote.extraNote!;
    }

    // Deep copy of quote items to avoid reference issues
    quoteItems = quote.items
        .map((item) => QuoteItem(
              id: item.id,
              quoteId: item.quoteId,
              description: item.description,
              quantity: item.quantity,
              unit: item.unit,
              price: item.price,
              vatRate: item.vatRate,
              marginPercentage: item.marginPercentage,
            ))
        .toList();

    // Controller'ları yeniden oluştur (async yüklemeden sonra)
    _initItemControllers();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerRepController.dispose();
    _phoneController.dispose();
    _paymentTermController.dispose();
    _noteController.dispose();
    _extraNoteController.dispose(); // ExtraNote controller'ı dispose
    _descriptionController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _marginController.dispose();
    _productSearchController.dispose(); // Ürün arama controller'ı dispose

    // Ürün satırı düzenleme controller'larını dispose
    for (var controller in _itemDescriptionControllers.values) {
      controller.dispose();
    }
    for (var controller in _itemQuantityControllers.values) {
      controller.dispose();
    }
    for (var controller in _itemPriceControllers.values) {
      controller.dispose();
    }
    for (var controller in _itemMarginControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> _openManualProductForm() async {
    // Manuel ürün formuna yönlendir - kullanıcının girdiği bilgileri parametre olarak gönder
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManualProductFormScreen(
          initialName: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
          initialBuyPrice: _priceController.text.isNotEmpty ? double.tryParse(_priceController.text) : null,
        ),
      ),
    );

    // Eğer ürün eklendiyse (result = Product), teklif listesine ekle
    if (result != null && result is Product) {
      final newItem = QuoteItem(
        id: '',
        quoteId: '',
        description: result.name,
        quantity: _quantityController.text.isNotEmpty ? double.tryParse(_quantityController.text) ?? 1 : 1,
        unit: _selectedUnit,
        price: result.salePriceExcludingVat, // Hesaplanmış satış fiyatı (KDV hariç)
        vatRate: result.vatRate,
        marginPercentage: result.marginPercentage,
      );

      setState(() {
        quoteItems.add(newItem);

        // Add controllers for the new item
        final index = quoteItems.length - 1;
        _itemDescriptionControllers[index] =
            TextEditingController(text: newItem.description);
        _itemQuantityControllers[index] =
            TextEditingController(text: newItem.quantity.toString());
        _itemPriceControllers[index] =
            TextEditingController(text: newItem.price.toString());
        _itemMarginControllers[index] =
            TextEditingController(text: newItem.marginPercentage.toString());
        _itemUnitValues[index] = newItem.unit;
        _itemEditModes[index] = false;

        // Clear the input fields
        _descriptionController.clear();
        _quantityController.clear();
        _priceController.clear();
        _selectedUnit = 'adet';
        _selectedVatRate = 20;
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      // If the item has an ID, track it as deleted
      final item = quoteItems[index];
      if (item.id.isNotEmpty) {
        _deletedItemIds.add(item.id);
      }

      // Remove from the list
      quoteItems.removeAt(index);

      // Clean up controllers for the removed item
      _itemDescriptionControllers.remove(index);
      _itemQuantityControllers.remove(index);
      _itemPriceControllers.remove(index);
      _itemMarginControllers.remove(index);
      _itemUnitValues.remove(index);
      _itemEditModes.remove(index);

      // Reassign controllers to match new indices
      _rebuildControllers();
    });
  }

  // Rebuild all controllers after item removal to maintain correct indices
  void _rebuildControllers() {
    final tempControllers =
        Map<int, TextEditingController>.from(_itemDescriptionControllers);
    final tempQuantityControllers =
        Map<int, TextEditingController>.from(_itemQuantityControllers);
    final tempPriceControllers =
        Map<int, TextEditingController>.from(_itemPriceControllers);
    final tempMarginControllers =
        Map<int, TextEditingController>.from(_itemMarginControllers);
    final tempUnitValues = Map<int, String>.from(_itemUnitValues);
    final tempEditModes = Map<int, bool>.from(_itemEditModes);

    _itemDescriptionControllers.clear();
    _itemQuantityControllers.clear();
    _itemPriceControllers.clear();
    _itemMarginControllers.clear();
    _itemUnitValues.clear();
    _itemEditModes.clear();

    for (int i = 0; i < quoteItems.length; i++) {
      // Find the old index for this item or create new controllers
      final oldIndex = tempControllers.keys
          .toList()
          .where((idx) =>
              idx < quoteItems.length &&
              tempControllers[idx]?.text == quoteItems[i].description)
          .firstOrNull;

      if (oldIndex != null) {
        // Reuse existing controllers
        _itemDescriptionControllers[i] = tempControllers[oldIndex]!;
        _itemQuantityControllers[i] = tempQuantityControllers[oldIndex]!;
        _itemPriceControllers[i] = tempPriceControllers[oldIndex]!;
        _itemMarginControllers[i] = tempMarginControllers[oldIndex]!;
        _itemUnitValues[i] = tempUnitValues[oldIndex]!;
        _itemEditModes[i] = tempEditModes[oldIndex] ?? false;
      } else {
        // Create new controllers
        _itemDescriptionControllers[i] =
            TextEditingController(text: quoteItems[i].description);
        _itemQuantityControllers[i] =
            TextEditingController(text: quoteItems[i].quantity.toString());
        _itemPriceControllers[i] =
            TextEditingController(text: quoteItems[i].price.toString());
        _itemMarginControllers[i] =
            TextEditingController(text: quoteItems[i].marginPercentage.toString());
        _itemUnitValues[i] = quoteItems[i].unit;
        _itemEditModes[i] = false;
      }
    }
  }

  void _toggleEditMode(int index) {
    setState(() {
      _itemEditModes[index] = !(_itemEditModes[index] ?? false);

      // Eğer düzenleme modu kapatılıyorsa, ürünü güncelle
      if (!(_itemEditModes[index] ?? true)) {
        _updateItemFromControllers(index);
      }
    });
  }

  void _updateItemFromControllers(int index) {
    if (index >= quoteItems.length) return;

    try {
      final description = _itemDescriptionControllers[index]?.text ?? '';
      final quantity =
          double.parse(_itemQuantityControllers[index]?.text ?? '0');
      final price = double.parse(_itemPriceControllers[index]?.text ?? '0');
      final margin = double.parse(_itemMarginControllers[index]?.text ?? '40');
      final unit = _itemUnitValues[index] ?? 'adet';

      setState(() {
        final currentId = quoteItems[index].id;
        final currentQuoteId = quoteItems[index].quoteId;
        final currentVatRate = quoteItems[index].vatRate;

        quoteItems[index] = QuoteItem(
          id: currentId,
          quoteId: currentQuoteId,
          description: description,
          quantity: quantity,
          unit: unit,
          price: price,
          vatRate: currentVatRate,
          marginPercentage: margin,
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: Geçersiz sayı formatı: $e')),
      );
    }
  }

  Map<String, double> _calculateTotals() {
    // ✅ YENİ: QuoteItemManager servisi kullan
    return _serviceLocator.quoteItems.calculateTotals(quoteItems);
  }

  double calculateProfitMargin(QuoteItem item) {
    // Find matching product by name with more flexible matching
    Product? matchingProduct;
    try {
      // Normalize description for comparison
      final normalizedDescription = item.description.trim().toLowerCase();

      matchingProduct = availableProducts.firstWhere(
          (product) =>
              product.name.trim().toLowerCase() == normalizedDescription,
          orElse: () {
        // If exact match fails, try partial match
        var bestMatch = availableProducts
            .where((p) =>
                normalizedDescription.contains(p.name.trim().toLowerCase()) ||
                p.name.trim().toLowerCase().contains(normalizedDescription))
            .toList();

        if (bestMatch.isNotEmpty) {
          // Sort by name length (longer names are likely more specific matches)
          bestMatch.sort((a, b) => b.name.length.compareTo(a.name.length));
          return bestMatch.first;
        }

        throw Exception('No match found');
      });
    } catch (e) {
      // No matching product found
      return 45.0; // Default margin
    }

    // Calculate cost price (purchase price)
    final costPrice = matchingProduct.specialPrice;

    // Calculate selling price
    final sellingPrice = item.price;

    if (costPrice > 0 && sellingPrice > 0) {
      // Calculate profit margin percentage
      return ((sellingPrice - costPrice) / sellingPrice) * 100;
    }

    // Default margin if price is zero
    return 45.0;
  }

  Future<void> _previewQuote() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        _setLoading(true);
        final quote = _createQuoteFromForm(isDraft: false);
        await pdfExportService.previewQuote(context, quote);
        _setLoading(false);
      } catch (e) {
        _setLoading(false);
        _showErrorMessage('Hata: $e');
      }
    }
  }

  /// SOLID: Sadece veritabanına kaydetme işlemi
  Future<Quote> _saveQuoteToDatabase(Quote quote) async {
    if (widget.existingQuote != null && widget.existingQuote!.id != '0') {
      return await _apiService.updateQuote(quote);
    } else {
      return await _apiService.createQuote(quote);
    }
  }

  /// Teklifi oluşturur ve helper fonksiyonlarla döner
  Quote _createQuoteFromForm({bool isDraft = false}) {
    final activeItems = _getActiveItems();
    final totals = _calculateTotals();

    return Quote(
      id: widget.existingQuote?.id ?? '0',
      customerName: _customerNameController.text.isEmpty && isDraft
          ? 'Taslak'
          : _customerNameController.text,
      representative: _customerRepController.text,
      phone: _phoneController.text,
      paymentTerm: _paymentTermController.text,
      note: _noteController.text,
      extraNote: _extraNoteController.text.isNotEmpty
          ? _extraNoteController.text
          : null,
      items: activeItems,
      createdAt: widget.existingQuote?.createdAt ?? DateTime.now(),
      modifiedAt: widget.existingQuote != null ? DateTime.now() : null,
      totalAmount: totals['subtotal']!,
      vatAmount: totals['vat']!,
      isDraft: isDraft,
    );
  }

  /// Sadece database'e kaydet (PDF oluşturma YOK)
  /// Bu teklifi kesinleştirir (isDraft=false), artık taslak değil bitmiş teklif olur
  Future<void> _generateAndSaveQuote() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        _setLoading(true);

        final quote = _createQuoteFromForm(isDraft: false);

        // Sadece database'e kaydet (PDF YOK)
        final savedQuote = await _saveQuoteToDatabase(quote);

        if (mounted) {
          _showSuccessMessage(
              'Teklif başarıyla ${widget.existingQuote != null ? 'güncellendi' : 'oluşturuldu'} ve kaydedildi');
          Navigator.pop(context, savedQuote);
        }
      } catch (e) {
        _showErrorMessage('Hata: $e');
      } finally {
        _setLoading(false);
      }
    }
  }

  // ========== PDF Kaydetme (DRY - Generic) ==========

  /// DRY: Generic PDF kaydetme fonksiyonu - hem KDV detaylı hem KDV gizli için
  /// Database'e kaydet + PDF export (native file picker ile konum seçtir)
  Future<void> _generateAndSavePdf({required bool withVatIncluded}) async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        _setLoading(true);

        final quote = _createQuoteFromForm(isDraft: false);

        // 1. Database'e kaydet
        final savedQuote = await _saveQuoteToDatabase(quote);

        // 2. PDF oluştur - parametreye göre
        String? pdfPath;
        try {
          pdfPath = withVatIncluded
              ? await pdfExportService.exportQuoteWithVatIncluded(savedQuote)
              : await pdfExportService.exportQuote(savedQuote);
        } catch (pdfError) {
          log('PDF oluşturma hatası: $pdfError');
          _showInfoMessage(
              'Teklif kaydedildi ama PDF oluşturulamadı: $pdfError',
              backgroundColor: Colors.orange);
          return;
        }

        if (mounted && pdfPath != null) {
          final pdfType = withVatIncluded ? 'KDV Dahil' : 'KDV Detaylı';
          _showSuccessMessage('PDF başarıyla kaydedildi ($pdfType)\nPDF: $pdfPath');
          log(pdfPath);
          Navigator.pop(context, savedQuote);
        }
      } catch (e) {
        _showErrorMessage('Hata: $e');
      } finally {
        _setLoading(false);
      }
    }
  }

  // ========== Preview Fonksiyonları ==========

  Future<void> _previewQuoteWithVatIncluded() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        _setLoading(true);
        final quote = _createQuoteFromForm(isDraft: false);
        await pdfExportService.previewQuoteWithVatIncluded(context, quote);
        _setLoading(false);
      } catch (e) {
        _setLoading(false);
        _showErrorMessage('Hata: $e');
      }
    }
  }

  /// Taslak kaydetme (sessizce, hata gösterme)
  Future<Quote?> _saveDraft() async {
    if (quoteItems.isEmpty) {
      return null;
    }

    try {
      final quote = _createQuoteFromForm(isDraft: true);
      final savedQuote = await _saveQuoteToDatabase(quote);
      return savedQuote;
    } catch (e) {
      log('Taslak kaydetme hatası: $e');
      return null;
    }
  }

  /// Manuel kaydetme (sadece database, PDF yok)
  Future<void> _saveManually() async {
    if (quoteItems.isEmpty) {
      _showInfoMessage('Teklife en az bir ürün eklemelisiniz',
          backgroundColor: Colors.orange);
      return;
    }

    try {
      _setLoading(true);

      final quote = _createQuoteFromForm(isDraft: true);
      final savedQuote = await _saveQuoteToDatabase(quote);

      if (mounted) {
        _showSuccessMessage(widget.existingQuote != null
            ? 'Teklif başarıyla güncellendi'
            : 'Teklif taslak olarak kaydedildi');
        Navigator.of(context).pop(savedQuote);
      }
    } catch (e) {
      _showErrorMessage(ErrorHandler.getUserMessage(e));
    } finally {
      _setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = _calculateTotals();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Geri basıldığında taslak kaydet ve döndür
        final savedQuote = await _saveDraft();

        if (context.mounted) {
          Navigator.of(context).pop(savedQuote);
        }
      },
      child: Scaffold(
        appBar: AppBar(
        title: Text(widget.existingQuote != null
            ? 'Teklifi Düzenle'
            : 'Teklif Oluştur'),
        actions: [
          if (quoteItems.isNotEmpty) ...[
            // Manuel kaydetme butonu
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Kaydet (Yazdırmadan)',
              onPressed: _saveManually,
            ),
            // KDV detaylı PDF (mevcut)
            IconButton(
              icon: const Icon(Icons.preview),
              tooltip: 'PDF Önizleme (KDV Detaylı)',
              onPressed: _previewQuote,
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'PDF Kaydet (KDV Detaylı)',
              onPressed: () => _generateAndSavePdf(withVatIncluded: false),
            ),
            // YENİ: KDV dahil (KDV gizli) PDF
            IconButton(
              icon: const Icon(Icons.money_off),
              tooltip: 'PDF Önizleme (KDV Dahil)',
              onPressed: _previewQuoteWithVatIncluded,
            ),
            IconButton(
              icon: const Icon(Icons.attach_money),
              tooltip: 'PDF Kaydet (KDV Dahil)',
              onPressed: () => _generateAndSavePdf(withVatIncluded: true),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCustomerInfoCard(),
                      const SizedBox(height: 16),
                      _buildProductsCard(totals),
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: quoteItems.isNotEmpty ? _generateAndSaveQuote : null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
          ),
          child: Text(widget.existingQuote != null
              ? 'Teklifi Güncelle'
              : 'Teklifi Oluştur'),
        ),
      ),
      ),
    );
  }

  Widget _buildCustomerInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Müşteri Bilgileri',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _customerNameController,
              decoration: const InputDecoration(
                labelText: 'Müşteri Adı',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Müşteri adı gerekli';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _customerRepController,
              decoration: const InputDecoration(
                labelText: 'Firma Yetkilisi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Telefon',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _paymentTermController,
                    decoration: const InputDecoration(
                      labelText: 'Ödeme Şekli',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Not',
                border: OutlineInputBorder(),
                hintText: 'Teklif için özel not ekleyin',
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _extraNoteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Ek Not (Opsiyonel)',
                border: OutlineInputBorder(),
                hintText: 'Teklif için ek not ekleyin',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsCard(Map<String, double> totals) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ürünler',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final products = await _apiService.getProducts();
                      if (!mounted) return;

                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) =>
                            _buildProductSelectionSheet(products),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Hata: $e')),
                      );
                    }
                  },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Katalogdan Ekle'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                // Mobil/desktop ayırımı
                final isMobile = constraints.maxWidth < 800;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildItemsTable(totals, isMobile: isMobile),
                );
              },
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Ara Toplam: ${numberFormat.format(totals['subtotal']!)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    'KDV (%20): ${numberFormat.format(totals['vat']!)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Divider(),
                  Text(
                    'Genel Toplam: ${numberFormat.format(totals['total']!)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _showQuantityDialog(BuildContext context, Product product) async {
    final quantityController = TextEditingController(text: '1');
    String selectedUnit = 'adet';

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Miktar ve Birim Girin'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fiyat: ${numberFormat.format(product.calculatedPrice)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  DecimalInputField(
                    controller: quantityController,
                    labelText: 'Miktar',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedUnit,
                    decoration: const InputDecoration(
                      labelText: 'Birim',
                      border: OutlineInputBorder(),
                    ),
                    items: unitOptions
                        .map((unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedUnit = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final quantity = double.tryParse(quantityController.text);
                    if (quantity != null && quantity > 0) {
                      Navigator.of(context).pop({
                        'quantity': quantity,
                        'unit': selectedUnit,
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Geçerli bir miktar girin')),
                      );
                    }
                  },
                  child: const Text('Ekle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildProductSelectionSheet(List<Product> products) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          // Filtered products based on search query
          final filteredProducts = products.where((product) {
            if (_productSearchQuery.isEmpty) return true;
            return product.name.toLowerCase().contains(_productSearchQuery.toLowerCase()) ||
                   product.productCode.toLowerCase().contains(_productSearchQuery.toLowerCase());
          }).toList();

          return Column(
            children: [
              AppBar(
                title: const Text('Ürün Seç'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _productSearchController,
                  decoration: InputDecoration(
                    hintText: 'Ürün ara...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _productSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setModalState(() {
                                _productSearchController.clear();
                                _productSearchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setModalState(() {
                      _productSearchQuery = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return ListTile(
                  title: Text(product.name),
                  subtitle: Text(
                    'Liste: ${numberFormat.format(product.listPrice)}\n'
                    'KDV Hariç: ${numberFormat.format(product.calculatedPrice)}',
                  ),
                  onTap: () async {
                    // Show quantity and unit dialog
                    final result = await _showQuantityDialog(context, product);

                    if (result == null) {
                      return; // User cancelled
                    }

                    final quantity = result['quantity'] as double;
                    final unit = result['unit'] as String;

                    if (quantity <= 0) {
                      return; // Invalid quantity
                    }

                    if (!mounted) return;

                    // Check if product already exists in quote
                    int existingIndex = quoteItems
                        .indexWhere((item) => item.description == product.name);

                    if (existingIndex >= 0) {
                      // Update existing item quantity
                      setState(() {
                        final updatedQuantity =
                            quoteItems[existingIndex].quantity + quantity;
                        final currentId = quoteItems[existingIndex].id;
                        final currentQuoteId =
                            quoteItems[existingIndex].quoteId;

                        quoteItems[existingIndex] = QuoteItem(
                          id: currentId,
                          quoteId: currentQuoteId,
                          description: quoteItems[existingIndex].description,
                          quantity: updatedQuantity,
                          unit: quoteItems[existingIndex].unit,
                          price: quoteItems[existingIndex].price,
                          vatRate: quoteItems[existingIndex].vatRate,
                          marginPercentage: quoteItems[existingIndex].marginPercentage,
                        );

                        // Update the quantity controller
                        _itemQuantityControllers[existingIndex]?.text =
                            updatedQuantity.toString();
                      });

                      if (mounted && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('Ürün miktarı güncellendi: ${product.name} (${quantity.toStringAsFixed(0)} $unit eklendi)'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } else {
                      // Add new item
                      setState(() {
                        final newItem = QuoteItem(
                          id: '', // Empty ID for new items
                          quoteId: '',
                          description: product.name,
                          quantity: quantity,
                          unit: unit,
                          price: product.calculatedPrice,
                          vatRate: product.vatRate,
                          marginPercentage: product.marginPercentage,
                        );

                        // Create a new list with all existing items plus the new one
                        final updatedItems = List<QuoteItem>.from(quoteItems);
                        updatedItems.add(newItem);
                        quoteItems = updatedItems;

                        // Add controllers for the new item
                        final idx = quoteItems.length - 1;
                        _itemDescriptionControllers[idx] =
                            TextEditingController(text: newItem.description);
                        _itemQuantityControllers[idx] = TextEditingController(
                            text: newItem.quantity.toString());
                        _itemPriceControllers[idx] = TextEditingController(
                            text: newItem.price.toString());
                        _itemMarginControllers[idx] = TextEditingController(
                            text: newItem.marginPercentage.toString());
                        _itemUnitValues[idx] = newItem.unit;
                        _itemEditModes[idx] = false;
                      });
                    }

                    if (mounted && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItemsTable(Map<String, double> totals, {required bool isMobile}) {
    // Mobil için kompakt genişlikler, desktop için geniş genişlikler
    final double descriptionWidth = isMobile ? 150 : 250;
    final double quantityWidth = isMobile ? 60 : 80;
    final double priceWidth = isMobile ? 80 : 120;

    return DataTable(
      columnSpacing: isMobile ? 8 : 24, // Mobilde daha az boşluk
      horizontalMargin: isMobile ? 8 : 24,
      columns: const [
        DataColumn(label: Text('No')),
        DataColumn(label: Text('Açıklama')),
        DataColumn(label: Text('Miktar')),
        DataColumn(label: Text('Birim')),
        DataColumn(label: Text('Fiyat')),
        DataColumn(label: Text('KDV')),
        DataColumn(label: Text('Toplam')),
        DataColumn(label: Text('İşlemler')), // Actions column
      ],
      rows: [
        // Mevcut ürünler
        ...quoteItems.asMap().entries.map(
          (entry) {
            final index = entry.key;
            final item = entry.value;
            final isEditing = _itemEditModes[index] ?? false;

            return DataRow(
              cells: [
                DataCell(Text('${index + 1}')),
                DataCell(
                  isEditing
                      ? SizedBox(
                          width: descriptionWidth,
                          child: TextField(
                            controller: _itemDescriptionControllers[index]!,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                            ),
                          ),
                        )
                      : SizedBox(
                          width: descriptionWidth,
                          child: Text(
                            item.description,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                ),
                DataCell(
                  isEditing
                      ? SizedBox(
                          width: quantityWidth,
                          child: DecimalInputField(
                            controller: _itemQuantityControllers[index]!,
                            labelText: '',
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        )
                      : Text(item.quantity.toString()),
                ),
                DataCell(
                  isEditing
                      ? DropdownButton<String>(
                          value: _itemUnitValues[index],
                          isExpanded: false,
                          isDense: true,
                          items: unitOptions
                              .map((unit) => DropdownMenuItem(
                                    value: unit,
                                    child: Text(unit),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _itemUnitValues[index] = value;
                              });
                            }
                          },
                        )
                      : Text(item.unit),
                ),
                DataCell(
                  isEditing
                      ? SizedBox(
                          width: priceWidth,
                          child: DecimalInputField(
                            controller: _itemPriceControllers[index]!,
                            labelText: '',
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        )
                      : Text(numberFormat.format(item.price)),
                ),
                DataCell(Text('%${item.vatRate.toInt()}')), // KDV oranını göster
                DataCell(Text(numberFormat.format(item.quantity * item.price))),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(isEditing ? Icons.save : Icons.edit),
                        iconSize: isMobile ? 20 : 24,
                        color: isEditing ? Colors.green : Colors.blue,
                        padding: EdgeInsets.all(isMobile ? 4 : 8),
                        constraints: BoxConstraints(
                          minWidth: isMobile ? 32 : 40,
                          minHeight: isMobile ? 32 : 40,
                        ),
                        onPressed: () => _toggleEditMode(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        iconSize: isMobile ? 20 : 24,
                        color: Colors.red,
                        padding: EdgeInsets.all(isMobile ? 4 : 8),
                        constraints: BoxConstraints(
                          minWidth: isMobile ? 32 : 40,
                          minHeight: isMobile ? 32 : 40,
                        ),
                        onPressed: () => _removeItem(index),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        // Manuel giriş satırı
        DataRow(
          cells: [
            DataCell(Text('${quoteItems.length + 1}')),
            DataCell(
              SizedBox(
                width: descriptionWidth,
                child: TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    hintText: 'Açıklama',
                    isDense: true,
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            DataCell(
              SizedBox(
                width: quantityWidth,
                child: DecimalInputField(
                  controller: _quantityController,
                  labelText: '',
                  hintText: 'Miktar',
                  decoration: const InputDecoration(
                    hintText: 'Miktar',
                    isDense: true,
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            DataCell(
              DropdownButton<String>(
                value: _selectedUnit,
                isDense: true,
                items: unitOptions
                    .map((unit) => DropdownMenuItem(
                          value: unit,
                          child: Text(unit),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedUnit = value!;
                  });
                },
              ),
            ),
            DataCell(
              SizedBox(
                width: priceWidth,
                child: DecimalInputField(
                  controller: _priceController,
                  labelText: '',
                  hintText: 'Fiyat',
                  decoration: const InputDecoration(
                    hintText: 'Fiyat',
                    isDense: true,
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            DataCell(
              DropdownButton<double>(
                value: _selectedVatRate,
                isDense: true,
                items: [10.0, 20.0]
                    .map((vat) => DropdownMenuItem(
                          value: vat,
                          child: Text('%${vat.toInt()}'),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedVatRate = value!;
                  });
                },
              ),
            ),
            const DataCell(Text('')), // For total
            DataCell(
              IconButton(
                icon: const Icon(Icons.add_circle),
                iconSize: isMobile ? 20 : 24,
                color: Colors.green,
                padding: EdgeInsets.all(isMobile ? 4 : 8),
                constraints: BoxConstraints(
                  minWidth: isMobile ? 32 : 40,
                  minHeight: isMobile ? 32 : 40,
                ),
                onPressed: _openManualProductForm,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
