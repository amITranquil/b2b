// lib/core/services/i_quote_item_manager.dart
import '../../models/quote.dart';
import '../../models/product.dart';

/// Single Responsibility Principle (SRP)
/// Dedicated service for managing quote items operations
abstract class IQuoteItemManager {
  /// Add a product to quote items
  /// Returns updated list of quote items
  List<QuoteItem> addProduct({
    required List<QuoteItem> currentItems,
    required Product product,
    required double quantity,
    required String unit,
  });

  /// Add a manual item to quote items
  List<QuoteItem> addManualItem({
    required List<QuoteItem> currentItems,
    required String description,
    required double quantity,
    required String unit,
    required double price,
    required double vatRate,
  });

  /// Update existing item
  List<QuoteItem> updateItem({
    required List<QuoteItem> currentItems,
    required int index,
    required QuoteItem updatedItem,
  });

  /// Remove item by index
  List<QuoteItem> removeItem({
    required List<QuoteItem> currentItems,
    required int index,
  });

  /// Merge two lists of quote items
  /// Combines quantities for duplicate items
  List<QuoteItem> mergeItems({
    required List<QuoteItem> existingItems,
    required List<QuoteItem> newItems,
  });

  /// Calculate totals for quote items
  Map<String, double> calculateTotals(List<QuoteItem> items);

  /// Find if product already exists in items (case-insensitive)
  int findItemIndex({
    required List<QuoteItem> items,
    required String description,
  });
}
