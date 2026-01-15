// lib/screens/quotes_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/quote.dart';
import '../services/api_service.dart';
import '../services/pdf_export_service.dart';
import 'quote_form_screen.dart';

class QuotesScreen extends StatefulWidget {
  const QuotesScreen({super.key});

  @override
  QuotesScreenState createState() => QuotesScreenState();
}

class QuotesScreenState extends State<QuotesScreen> {
  final ApiService _apiService = ApiService();
  final PdfExportService _pdfExportService = PdfExportService();
  final numberFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
  List<Quote> _quotes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadQuotes();
  }

  Future<void> _loadQuotes() async {
    setState(() => _isLoading = true);
    try {
      final quotes = await _apiService.getQuotes();
      setState(() {
        _quotes = quotes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  /// DRY: Generic PDF export - hem KDV detaylı hem KDV gizli için
  Future<void> _exportQuoteToPdf(Quote quote, {required bool withVatIncluded}) async {
    try {
      final pdfPath = withVatIncluded
          ? await _pdfExportService.exportQuoteWithVatIncluded(quote)
          : await _pdfExportService.exportQuote(quote);

      if (pdfPath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF kaydetme işlemi iptal edildi'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (mounted) {
        final pdfType = withVatIncluded ? 'KDV Dahil' : 'KDV Detaylı';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF başarıyla kaydedildi ($pdfType)\n$pdfPath'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF kaydetme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // QuotesScreen artık bir Tab içinde olduğu için kendi AppBar'ına ihtiyacı yok
    // Yeni teklif butonu ProductsScreen'in AppBar'ında
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // Refresh butonu
              Container(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _loadQuotes,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Yenile'),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildQuotesList()),
            ],
          );
  }

  Widget _buildQuotesList() {
    if (_quotes.isEmpty) {
      return const Center(
        child: Text('Henüz teklif bulunmuyor'),
      );
    }

    return ListView.builder(
      itemCount: _quotes.length,
      itemBuilder: (context, index) {
        final quote = _quotes[index];
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: quote.isDraft
              ? (isDarkMode
                  ? Colors.orange.shade900.withValues(alpha: 0.2)  // Dark mode: soft dark orange
                  : Colors.orange.shade50)  // Light mode: soft light orange
              : null,
          child: ListTile(
            leading: quote.isDraft
                ? Icon(Icons.edit_note,
                    color: isDarkMode ? Colors.orange.shade300 : Colors.orange.shade700)
                : Icon(Icons.description,
                    color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700),
            title: Row(
              children: [
                Expanded(child: Text(quote.customerName)),
                if (quote.isDraft)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.orange.shade700 : Colors.orange.shade600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'TASLAK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tarih: ${DateFormat('dd.MM.yyyy').format(quote.createdAt)}',
                ),
                Text(
                    'Toplam: ${numberFormat.format(quote.totalAmount + quote.vatAmount)}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  color: Colors.red,
                  tooltip: 'PDF İndir (KDV Detaylı)',
                  onPressed: () => _exportQuoteToPdf(quote, withVatIncluded: false),
                ),
                IconButton(
                  icon: const Icon(Icons.attach_money),
                  color: Colors.green,
                  tooltip: 'PDF İndir (KDV Dahil)',
                  onPressed: () => _exportQuoteToPdf(quote, withVatIncluded: true),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Düzenle',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QuoteFormScreen(
                          existingQuote: quote,
                        ),
                      ),
                    ).then((_) => _loadQuotes());
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  color: Colors.red,
                  tooltip: 'Sil',
                  onPressed: () => _showDeleteConfirmation(quote),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDeleteConfirmation(Quote quote) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Teklifi Sil'),
        content: Text(
            '${quote.customerName} teklifini silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      try {
        await _apiService.deleteQuote(quote.id);
        _loadQuotes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Teklif silindi')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e')),
          );
        }
      }
    }
  }
}
