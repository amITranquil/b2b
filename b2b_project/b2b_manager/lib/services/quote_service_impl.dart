// lib/services/quote_service_impl.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/error/error_handler.dart';
import '../core/error/exceptions.dart';
import '../core/services/i_quote_service.dart';
import '../models/quote.dart';

/// Dependency Inversion Principle (DIP)
/// Concrete implementation of IQuoteService
class QuoteServiceImpl implements IQuoteService {
  final String baseUrl;
  final http.Client httpClient;

  QuoteServiceImpl({
    required this.baseUrl,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  @override
  Future<List<Quote>> getQuotes() async {
    try {
      final response = await httpClient.get(Uri.parse('$baseUrl/quotes'));

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          return [];
        }

        final List<dynamic> jsonList = json.decode(responseBody);
        return jsonList.map((json) => Quote.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to load quotes',
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      ErrorHandler.logError(e, context: 'QuoteService.getQuotes');
      throw NetworkException('Sunucuya bağlanılamadı', originalError: e);
    } catch (e) {
      ErrorHandler.logError(e, context: 'QuoteService.getQuotes');
      rethrow;
    }
  }

  @override
  Future<Quote> getQuote(String id) async {
    try {
      final response = await httpClient.get(Uri.parse('$baseUrl/quotes/$id'));

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          throw ApiException('Empty response when fetching quote $id');
        }

        return Quote.fromJson(json.decode(responseBody));
      } else if (response.statusCode == 404) {
        throw NotFoundException('Teklif bulunamadı: $id');
      } else {
        throw ApiException(
          'Failed to load quote',
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      ErrorHandler.logError(e, context: 'QuoteService.getQuote');
      throw NetworkException('Sunucuya bağlanılamadı', originalError: e);
    } catch (e) {
      ErrorHandler.logError(e, context: 'QuoteService.getQuote');
      rethrow;
    }
  }

  @override
  Future<Quote> createQuote(Quote quote) async {
    try {
      final quoteToSend = quote.toJson();

      final response = await httpClient.post(
        Uri.parse('$baseUrl/quotes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(quoteToSend),
      );

      if (response.statusCode == 201) {
        final responseBody = response.body;
        return Quote.fromJson(json.decode(responseBody));
      } else if (response.statusCode == 401) {
        throw UnauthorizedException('Yetkilendirme hatası: Lütfen yeniden giriş yapın');
      } else if (response.statusCode == 403) {
        throw UnauthorizedException('Bu işlem için yetkiniz bulunmuyor');
      } else {
        throw ApiException(
          'Teklif oluşturma hatası: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      ErrorHandler.logError(e, context: 'QuoteService.createQuote');
      throw NetworkException('Sunucuya bağlanılamadı', originalError: e);
    } catch (e) {
      ErrorHandler.logError(e, context: 'QuoteService.createQuote');
      rethrow;
    }
  }

  @override
  Future<Quote> updateQuote(Quote quote) async {
    try {
      final quoteToSend = quote.toJson();

      final response = await httpClient.put(
        Uri.parse('$baseUrl/quotes/${quote.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(quoteToSend),
      );

      if (response.statusCode == 200) {
        final responseBody = response.body;
        return Quote.fromJson(json.decode(responseBody));
      } else {
        throw ApiException(
          'Failed to update quote: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      ErrorHandler.logError(e, context: 'QuoteService.updateQuote');
      throw NetworkException('Sunucuya bağlanılamadı', originalError: e);
    } catch (e) {
      ErrorHandler.logError(e, context: 'QuoteService.updateQuote');
      rethrow;
    }
  }

  @override
  Future<void> deleteQuote(String id) async {
    try {
      final response = await httpClient.delete(Uri.parse('$baseUrl/quotes/$id'));

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw ApiException(
          'Failed to delete quote',
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      ErrorHandler.logError(e, context: 'QuoteService.deleteQuote');
      throw NetworkException('Sunucuya bağlanılamadı', originalError: e);
    } catch (e) {
      ErrorHandler.logError(e, context: 'QuoteService.deleteQuote');
      rethrow;
    }
  }
}
