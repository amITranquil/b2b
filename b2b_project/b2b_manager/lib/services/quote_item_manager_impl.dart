// lib/services/quote_item_manager_impl.dart
import '../core/services/i_quote_item_manager.dart';
import '../models/product.dart';
import '../models/quote.dart';

/// Single Responsibility Principle (SRP)
/// Manages all quote item operations with proper business logic
class QuoteItemManagerImpl implements IQuoteItemManager {
  @override
  List<QuoteItem> addProduct({
    required List<QuoteItem> currentItems,
    required Product product,
    required double quantity,
    required String unit,
  }) {
    // Create a new list to maintain immutability
    final updatedItems = List<QuoteItem>.from(currentItems);

    // Calculate price excluding VAT
    final priceExcludingVat = product.vatRate > 0
        ? product.myPrice / (1 + product.vatRate / 100)
        : product.myPrice;

    // Check if product already exists (case-insensitive)
    final existingIndex = findItemIndex(
      items: updatedItems,
      description: product.name,
    );

    if (existingIndex >= 0) {
      // Update existing item quantity
      final existingItem = updatedItems[existingIndex];
      updatedItems[existingIndex] = QuoteItem(
        id: existingItem.id,
        quoteId: existingItem.quoteId,
        description: existingItem.description,
        quantity: existingItem.quantity + quantity,
        unit: existingItem.unit,
        price: existingItem.price,
        vatRate: existingItem.vatRate,
      );
    } else {
      // Add new item
      updatedItems.add(QuoteItem(
        id: '',
        quoteId: '',
        description: product.name,
        quantity: quantity,
        unit: unit,
        price: priceExcludingVat,
        vatRate: product.vatRate,
      ));
    }

    return updatedItems;
  }

  @override
  List<QuoteItem> addManualItem({
    required List<QuoteItem> currentItems,
    required String description,
    required double quantity,
    required String unit,
    required double price,
    required double vatRate,
  }) {
    final updatedItems = List<QuoteItem>.from(currentItems);

    updatedItems.add(QuoteItem(
      id: '',
      quoteId: '',
      description: description,
      quantity: quantity,
      unit: unit,
      price: price,
      vatRate: vatRate,
    ));

    return updatedItems;
  }

  @override
  List<QuoteItem> updateItem({
    required List<QuoteItem> currentItems,
    required int index,
    required QuoteItem updatedItem,
  }) {
    if (index < 0 || index >= currentItems.length) {
      return currentItems;
    }

    final updatedItems = List<QuoteItem>.from(currentItems);
    updatedItems[index] = updatedItem;
    return updatedItems;
  }

  @override
  List<QuoteItem> removeItem({
    required List<QuoteItem> currentItems,
    required int index,
  }) {
    if (index < 0 || index >= currentItems.length) {
      return currentItems;
    }

    final updatedItems = List<QuoteItem>.from(currentItems);
    updatedItems.removeAt(index);
    return updatedItems;
  }

  @override
  List<QuoteItem> mergeItems({
    required List<QuoteItem> existingItems,
    required List<QuoteItem> newItems,
  }) {
    final mergedItems = List<QuoteItem>.from(existingItems);

    for (var newItem in newItems) {
      // Check if item already exists (case-insensitive)
      final existingIndex = findItemIndex(
        items: mergedItems,
        description: newItem.description,
      );

      if (existingIndex >= 0) {
        // Update quantity
        final existingItem = mergedItems[existingIndex];
        mergedItems[existingIndex] = QuoteItem(
          id: existingItem.id,
          quoteId: existingItem.quoteId,
          description: existingItem.description,
          quantity: existingItem.quantity + newItem.quantity,
          unit: existingItem.unit,
          price: existingItem.price,
          vatRate: existingItem.vatRate,
        );
      } else {
        // Add new item
        mergedItems.add(newItem);
      }
    }

    return mergedItems;
  }

  @override
  Map<String, double> calculateTotals(List<QuoteItem> items) {
    double subtotal = 0;
    double totalVat = 0;

    for (var item in items) {
      final itemSubtotal = item.quantity * item.price;
      final itemVat = itemSubtotal * (item.vatRate / 100);

      subtotal += itemSubtotal;
      totalVat += itemVat;
    }

    final total = subtotal + totalVat;

    return {
      'subtotal': subtotal,
      'vat': totalVat,
      'total': total,
    };
  }

  @override
  int findItemIndex({
    required List<QuoteItem> items,
    required String description,
  }) {
    // Case-insensitive, trim whitespace
    final normalizedSearch = description.trim().toLowerCase();

    return items.indexWhere(
      (item) => item.description.trim().toLowerCase() == normalizedSearch,
    );
  }
}
