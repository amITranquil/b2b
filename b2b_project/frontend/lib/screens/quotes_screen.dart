import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/quote.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import 'quote_detail_screen.dart';

class QuotesScreen extends StatefulWidget {
  const QuotesScreen({super.key});

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  final ApiService _apiService = ApiService();
  final ThemeService _themeService = ThemeService();
  final TextEditingController _searchController = TextEditingController();

  List<Quote> _quotes = [];
  List<Quote> _filteredQuotes = [];
  bool _isLoading = true;
  String? _error;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadQuotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadQuotes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final quotes = await _apiService.getQuotes();
      setState(() {
        _quotes = quotes;
        _filteredQuotes = quotes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Teklifler yüklenemedi: $e';
        _isLoading = false;
      });
    }
  }

  String _toUpperCaseTurkish(String text) {
    // Türkçe karakterleri koruyarak büyük harfe çevir
    return text
        .replaceAll('i', 'İ')
        .replaceAll('ı', 'I')
        .replaceAll('ş', 'Ş')
        .replaceAll('ğ', 'Ğ')
        .replaceAll('ü', 'Ü')
        .replaceAll('ö', 'Ö')
        .replaceAll('ç', 'Ç')
        .toUpperCase();
  }

  void _filterQuotes() {
    final searchQuery = _toUpperCaseTurkish(_searchController.text);

    setState(() {
      _filteredQuotes = _quotes.where((quote) {
        // Customer name filter - Türkçe karakterlere duyarlı
        final matchesName = searchQuery.isEmpty ||
            _toUpperCaseTurkish(quote.customerName).contains(searchQuery);

        // Date range filter - tarih karşılaştırmasını düzelt
        final matchesDate = _dateRange == null || _isDateInRange(quote.createdAt, _dateRange!);

        return matchesName && matchesDate;
      }).toList();
    });
  }

  bool _isDateInRange(DateTime date, DateTimeRange range) {
    // Sadece tarihleri karşılaştır (saati göz ardı et)
    final dateOnly = DateTime(date.year, date.month, date.day);
    final startOnly = DateTime(range.start.year, range.start.month, range.start.day);
    final endOnly = DateTime(range.end.year, range.end.month, range.end.day);

    return (dateOnly.isAtSameMomentAs(startOnly) || dateOnly.isAfter(startOnly)) &&
           (dateOnly.isAtSameMomentAs(endOnly) || dateOnly.isBefore(endOnly));
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateRange,
      locale: const Locale('tr', 'TR'),
    );

    if (picked != null && picked != _dateRange) {
      setState(() {
        _dateRange = picked;
      });
      _filterQuotes();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _dateRange = null;
    });
    _filterQuotes();
  }

  @override
  Widget build(BuildContext context) {
    // Theme artık MaterialApp seviyesinde yönetiliyor
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teklifler'),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: isDarkMode ? 'Açık Tema' : 'Koyu Tema',
            onPressed: _themeService.toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _loadQuotes,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_dateRange != null) _buildDateFilterChip(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              inputFormatters: [
                TextInputFormatter.withFunction((oldValue, newValue) {
                  return TextEditingValue(
                    text: _toUpperCaseTurkish(newValue.text),
                    selection: newValue.selection,
                  );
                }),
              ],
              decoration: InputDecoration(
                hintText: 'Müşteri adı ile ara...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterQuotes();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => _filterQuotes(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.calendar_today,
              color: _dateRange != null ? Theme.of(context).primaryColor : null,
            ),
            tooltip: 'Tarih filtrele',
            onPressed: _selectDateRange,
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterChip() {
    final formatter = DateFormat('dd.MM.yyyy');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Chip(
        label: Text(
          '${formatter.format(_dateRange!.start)} - ${formatter.format(_dateRange!.end)}',
        ),
        deleteIcon: const Icon(Icons.close, size: 18),
        onDeleted: _clearDateFilter,
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
              onPressed: _loadQuotes,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (_filteredQuotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.description_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty || _dateRange != null
                  ? 'Arama kriterlerine uygun teklif bulunamadı'
                  : 'Henüz teklif oluşturulmamış',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return _buildGridView();
        } else {
          return _buildListView();
        }
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredQuotes.length,
      itemBuilder: (context, index) {
        final quote = _filteredQuotes[index];
        return _buildQuoteCard(quote);
      },
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredQuotes.length,
      itemBuilder: (context, index) {
        final quote = _filteredQuotes[index];
        return _buildQuoteCard(quote);
      },
    );
  }

  Widget _buildQuoteCard(Quote quote) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final currencyFormatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuoteDetailScreen(quoteId: quote.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      quote.customerName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (quote.isDraft)
                    Chip(
                      label: const Text('TASLAK', style: TextStyle(fontSize: 11, color: Colors.white)),
                      backgroundColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.orange.shade800
                          : Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (quote.representative.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        quote.representative,
                        style: const TextStyle(color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              if (quote.phone.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      quote.phone,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    formatter.format(quote.createdAt.toLocal()),
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Toplam',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade400
                              : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        currencyFormatter.format(quote.totalAmount),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'KDV Dahil',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade400
                              : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        currencyFormatter.format(quote.grandTotal),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.lightBlue.shade300
                              : Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${quote.items.length} kalem',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
