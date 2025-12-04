// lib/core/services/i_quote_service.dart
import '../../models/quote.dart';

/// Interface Segregation Principle (ISP)
/// Quote işlemleri için ayrı interface
abstract class IQuoteService {
  Future<List<Quote>> getQuotes();
  Future<Quote> getQuote(String id);
  Future<Quote> createQuote(Quote quote);
  Future<Quote> updateQuote(Quote quote);
  Future<void> deleteQuote(String id);
}
