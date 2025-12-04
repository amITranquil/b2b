import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/quote.dart';
import '../services/api_service.dart';
import '../services/pdf_export_service_web.dart';

class QuoteDetailScreen extends StatefulWidget {
  final int quoteId;

  const QuoteDetailScreen({super.key, required this.quoteId});

  @override
  State<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends State<QuoteDetailScreen> {
  final ApiService _apiService = ApiService();
  final PdfExportServiceWeb _pdfService = PdfExportServiceWeb();
  Quote? _quote;
  bool _isLoading = true;
  String? _error;
  bool _showVatDetails = true; // KDV Detaylı = true, KDV Gizli = false

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final quote = await _apiService.getQuote(widget.quoteId);
      setState(() {
        _quote = quote;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Teklif yüklenemedi: $e';
        _isLoading = false;
      });
    }
  }

  void _toggleVatDisplay() {
    setState(() {
      _showVatDetails = !_showVatDetails;
    });
  }

  Future<void> _printQuote() async {
    if (_quote == null) return;

    try {
      await _pdfService.printPdf(_quote!, _showVatDetails);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yazdırma hatası: $e')),
        );
      }
    }
  }

  Future<void> _downloadPdf() async {
    if (_quote == null) return;

    try {
      final success = await _pdfService.downloadPdf(_quote!, _showVatDetails);
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF kaydedildi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF kaydetme hatası: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // Teklif detayı her zaman light theme olsun
    return Theme(
      data: ThemeData.light(useMaterial3: true),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Teklif Detayı'),
          actions: [
            if (_quote != null) ...[
              // KDV Toggle
              IconButton(
                icon: Icon(_showVatDetails ? Icons.visibility : Icons.visibility_off),
                tooltip: _showVatDetails ? 'KDV Gizle' : 'KDV Detaylı Göster',
                onPressed: _toggleVatDisplay,
              ),
              // Print
              IconButton(
                icon: const Icon(Icons.print),
                tooltip: 'Yazdır',
                onPressed: _printQuote,
              ),
              // Download
              IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'İndir',
                onPressed: _downloadPdf,
              ),
            ],
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Yenile',
              onPressed: _loadQuote,
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadQuote,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (_quote == null) {
      return const Center(child: Text('Teklif bulunamadı'));
    }

    return _buildQuoteDetail(_quote!);
  }

  Widget _buildQuoteDetail(Quote quote) {
    final dateFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final currencyFormatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Header - Company Info
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'URLA TEKNİK',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'DALGIÇ POMPA SIHHİ TESİSAT',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'ALTINTAŞ MAH. AHMET BESİM UYAL CAD.\nZEREN SANAYİ SİTESİ NO:4/A 16 İZMİR/URLA',
                        style: TextStyle(fontSize: 11),
                      ),
                      const Text(
                        'Tel: 0541 665 82 56 - 0532 324 02 87',
                        style: TextStyle(fontSize: 11),
                      ),
                      const Text(
                        'E-posta: contact@urlateknik.com | Web: www.urlateknik.com',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Customer Information Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'MÜŞTERİ BİLGİLERİ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (quote.isDraft)
                            const Chip(
                              label: Text('TASLAK', style: TextStyle(fontSize: 11)),
                              backgroundColor: Colors.orange,
                              padding: EdgeInsets.symmetric(horizontal: 8),
                            ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildInfoRow('Müşteri Adı:', quote.customerName),
                      if (quote.representative.isNotEmpty)
                        _buildInfoRow('Firma Yetkilisi:', quote.representative),
                      if (quote.phone.isNotEmpty)
                        _buildInfoRow('Telefon:', quote.phone),
                      if (quote.paymentTerm.isNotEmpty)
                        _buildInfoRow('Ödeme Şekli:', quote.paymentTerm),
                      _buildInfoRow(
                        'Tarih:',
                        dateFormatter.format(quote.createdAt.toLocal()),
                      ),
                      if (quote.modifiedAt != null)
                        _buildInfoRow(
                          'Güncelleme:',
                          dateFormatter.format(quote.modifiedAt!.toLocal()),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Items Table
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ÜRÜN/HİZMETLER',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth > 600) {
                            return _buildItemsTable(quote.items, currencyFormatter);
                          } else {
                            return _buildItemsList(quote.items, currencyFormatter);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Summary Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_showVatDetails) ...[
                        _buildSummaryRow(
                          'Ara Toplam:',
                          currencyFormatter.format(quote.totalAmount),
                          false,
                        ),
                        const SizedBox(height: 8),
                        _buildSummaryRow(
                          'KDV (%20):',
                          currencyFormatter.format(quote.vatAmount),
                          false,
                        ),
                        const Divider(height: 24),
                        _buildSummaryRow(
                          'GENEL TOPLAM:',
                          currencyFormatter.format(quote.grandTotal),
                          true,
                        ),
                      ] else ...[
                        _buildSummaryRow(
                          'TOPLAM:',
                          currencyFormatter.format(quote.grandTotal),
                          true,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Notes
              if (quote.note.isNotEmpty || (quote.extraNote?.isNotEmpty ?? false))
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (quote.note.isNotEmpty) ...[
                          const Text(
                            'Notlar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(quote.note),
                          if (quote.extraNote?.isNotEmpty ?? false)
                            const SizedBox(height: 16),
                        ],
                        if (quote.extraNote?.isNotEmpty ?? false) ...[
                          const Text(
                            'Ek Notlar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(quote.extraNote!),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Fixed Note
              const Card(
                elevation: 1,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    '* Bu fiyat teklifi oluşturulma ya da düzenlenme tarihinde geçerlidir.\n'
                    '* Garanti kapsamında olmayan durumlarda servis hizmeti ücretlidir.\n'
                    '* Arıza tespiti sonrasında belirlenecek malzeme ve işçilik bedeli ayrıca fiyatlandırılacaktır.',
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable(List<QuoteItem> items, NumberFormat formatter) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FixedColumnWidth(50),
        1: FlexColumnWidth(3),
        2: FixedColumnWidth(80),
        3: FixedColumnWidth(80),
        4: FixedColumnWidth(120),
        5: FixedColumnWidth(120),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade200),
          children: const [
            Padding(
              padding: EdgeInsets.all(8),
              child: Text('No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text('Açıklama', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text('Miktar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text('Birim', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text('Birim Fiyat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text('Tutar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right),
            ),
          ],
        ),
        ...items.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final item = entry.value;
          // KDV Gizli modda fiyatları KDV dahil göster
          final price = _showVatDetails ? item.price : item.price * (1 + item.vatRate / 100);
          final total = _showVatDetails ? item.total : item.quantity * price;

          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('$index', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(item.description, style: const TextStyle(fontSize: 11)),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(item.unit, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(formatter.format(price), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11)),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(formatter.format(total), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11)),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildItemsList(List<QuoteItem> items, NumberFormat formatter) {
    return Column(
      children: items.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final item = entry.value;
        // KDV Gizli modda fiyatları KDV dahil göster
        final price = _showVatDetails ? item.price : item.price * (1 + item.vatRate / 100);
        final total = _showVatDetails ? item.total : item.quantity * price;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$index. ${item.description}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${item.quantity} ${item.unit}', style: const TextStyle(fontSize: 11)),
                    Text(formatter.format(price), style: const TextStyle(fontSize: 11)),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tutar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    Text(
                      formatter.format(total),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isTotal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(width: 24),
        SizedBox(
          width: 150,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Theme.of(context).primaryColor : null,
            ),
          ),
        ),
      ],
    );
  }
}
