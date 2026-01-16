// lib/services/receipt_service.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../models/sale.dart';

class ReceiptService {
  final numberFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
  final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

  Future<void> generateReceipt(Sale sale, BuildContext context) async {
    // Türkçe karakter desteği için Google Fonts
    pw.Font? regularFont;
    pw.Font? boldFont;

    try {
      regularFont = await PdfGoogleFonts.nunitoRegular();
      boldFont = await PdfGoogleFonts.nunitoBold();
    } catch (e) {
      try {
        regularFont = await PdfGoogleFonts.robotoRegular();
        boldFont = await PdfGoogleFonts.robotoBold();
      } catch (e) {
        regularFont = await PdfGoogleFonts.openSansRegular();
        boldFont = await PdfGoogleFonts.openSansBold();
      }
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'URLA TEKNİK',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 20,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Perakende Satış Fişi',
                    style: pw.TextStyle(font: regularFont, fontSize: 12),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    dateFormat.format(sale.createdAt),
                    style: pw.TextStyle(font: regularFont, fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Divider(),
            pw.SizedBox(height: 8),

            // Items
            ...sale.items.map((item) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  item.productName,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 12,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '${item.quantity} ${item.unit} × ${numberFormat.format(item.price)}',
                      style: pw.TextStyle(font: regularFont, fontSize: 10),
                    ),
                    pw.Text(
                      numberFormat.format(item.total),
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
              ],
            )),

            pw.Divider(),
            pw.SizedBox(height: 8),

            // Subtotal
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Ara Toplam:',
                  style: pw.TextStyle(font: regularFont, fontSize: 12),
                ),
                pw.Text(
                  numberFormat.format(sale.subtotal),
                  style: pw.TextStyle(font: regularFont, fontSize: 12),
                ),
              ],
            ),

            pw.SizedBox(height: 8),
            pw.Divider(),
            pw.SizedBox(height: 8),

            // Total
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOPLAM:',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 16,
                  ),
                ),
                pw.Text(
                  numberFormat.format(sale.total),
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 18,
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 8),
            pw.Divider(),
            pw.SizedBox(height: 8),

            // Payment method
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Ödeme Yöntemi:',
                  style: pw.TextStyle(font: regularFont, fontSize: 10),
                ),
                pw.Text(
                  sale.paymentMethod.displayName,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 10,
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 16),
            pw.Divider(),
            pw.SizedBox(height: 8),

            // Mali değeri yoktur
            pw.Center(
              child: pw.Text(
                'MALİ DEĞERİ YOKTUR',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 10,
                ),
              ),
            ),

            pw.SizedBox(height: 8),

            // Footer
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'Bizi tercih ettiğiniz için teşekkürler!',
                    style: pw.TextStyle(font: regularFont, fontSize: 10),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'URLA TEKNİK © ${DateTime.now().year}',
                    style: pw.TextStyle(font: regularFont, fontSize: 8),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Generate PDF bytes
    final Uint8List pdfBytes = await pdf.save();

    // Show Syncfusion PDF preview
    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfPreviewScreen(
          pdfBytes: pdfBytes,
          fileName: 'Fiş_${dateFormat.format(sale.createdAt).replaceAll(':', '-')}.pdf',
        ),
      ),
    );
  }
}

// PDF Preview Screen with Syncfusion Viewer
class PdfPreviewScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String fileName;

  const PdfPreviewScreen({
    super.key,
    required this.pdfBytes,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiş Önizleme'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Yazdır',
            onPressed: () async {
              await Printing.layoutPdf(
                onLayout: (PdfPageFormat format) async => pdfBytes,
                name: fileName,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Paylaş',
            onPressed: () async {
              await Printing.sharePdf(
                bytes: pdfBytes,
                filename: fileName,
              );
            },
          ),
        ],
      ),
      body: SfPdfViewer.memory(
        pdfBytes,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
      ),
    );
  }
}
