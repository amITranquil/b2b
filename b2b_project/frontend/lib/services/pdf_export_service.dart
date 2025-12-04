import '../models/quote.dart';
import 'pdf_export_service_stub.dart'
    if (dart.library.html) 'pdf_export_service_web.dart'
    if (dart.library.io) 'pdf_export_service_mobile.dart';

abstract class PdfExportService {
  Future<void> printPdf(Quote quote, bool showVatDetails);
  Future<bool> downloadPdf(Quote quote, bool showVatDetails);

  factory PdfExportService() => createPdfExportService();
}
