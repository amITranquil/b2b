// lib/core/services/i_pdf_service.dart
import 'package:flutter/material.dart';
import '../../models/quote.dart';

/// Interface Segregation Principle (ISP)
/// PDF işlemleri için ayrı interface
abstract class IPdfService {
  Future<void> previewQuote(BuildContext context, Quote quote);
  Future<String?> exportQuote(Quote quote);

  // KDV gizli (ama fiyatlar KDV dahil) versiyonlar
  Future<void> previewQuoteWithVatIncluded(BuildContext context, Quote quote);
  Future<String?> exportQuoteWithVatIncluded(Quote quote);
}
