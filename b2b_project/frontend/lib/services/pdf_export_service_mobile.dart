import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/quote.dart';
import 'pdf_export_service.dart';

PdfExportService createPdfExportService() => PdfExportServiceMobile();

class PdfExportServiceMobile implements PdfExportService {
  static const String companyName = "URLA TEKNİK";
  static const String companyDesc = "DALGIÇ POMPA SIHHİ TESİSAT";
  static const String companyAddress =
      "ALTINTAŞ MAH. AHMET BESİM UYAL CAD. \nZEREN SANAYİ SİTESİ NO:4/A 16 İZMİR/URLA";
  static const String companyPhone = "0541 665 82 56 - 0532 324 02 87";
  static const String companyEmail = "contact@urlateknik.com";
  static const String companyWebsite = "www.urlateknik.com";
  static const String fixedNote =
      """* Bu fiyat teklifi oluşturulma ya da düzenlenme tarihinde geçerlidir.
* Garanti kapsamında olmayan durumlarda servis hizmeti ücretlidir.
* Arıza tespiti sonrasında belirlenecek malzeme ve işçilik bedeli ayrıca fiyatlandırılacaktır.""";

  final numberFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

  @override
  Future<bool> downloadPdf(Quote quote, bool showVatDetails) async {
    // Mobile platformlarda printing paketi kullanarak PDF paylaş
    final pdfDoc = await _generatePdfDocument(quote, showVatDetails);
    final bytes = await pdfDoc.save();

    final fileName =
        'teklif_${quote.customerName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(quote.createdAt)}.pdf';

    try {
      // Mobile'da printing paketinin shareFile fonksiyonu kullanılır
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('PDF paylaşma hatası: $e');
      }
      return false;
    }
  }

  @override
  Future<void> printPdf(Quote quote, bool showVatDetails) async {
    final pdfDoc = await _generatePdfDocument(quote, showVatDetails);
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => await pdfDoc.save());
  }

  Future<pw.Document> _generatePdfDocument(Quote quote, bool showVatDetails) async {
    final pdf = pw.Document();

    // SVG logo yüklemesi
    pw.SvgImage? svgLogo;
    try {
      final logoSources = ['assets/logo.svg', '../assets/logo.svg', 'logo.svg'];
      for (var path in logoSources) {
        try {
          final logoData = await rootBundle.loadString(path);
          svgLogo = pw.SvgImage(svg: logoData, width: 80, height: 80);
          break;
        } catch (e) {
          if (kDebugMode) print('Failed to load logo from \$path: \$e');
        }
      }
    } catch (e) {
      if (kDebugMode) print('SVG logo loading failed: \$e');
    }

    // Font yükleme - printing paketinin built-in fontlarını kullan
    final ttf = await PdfGoogleFonts.notoSansRegular();
    final ttfBold = await PdfGoogleFonts.notoSansBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(svgLogo, ttf, ttfBold),
              pw.SizedBox(height: 20),

              // Customer Info
              _buildCustomerInfo(quote, ttf, ttfBold),
              pw.SizedBox(height: 20),

              // Items Table
              if (showVatDetails)
                _buildItemsTable(quote, ttf, ttfBold)
              else
                _buildItemsTableWithVatIncluded(quote, ttf, ttfBold),

              pw.SizedBox(height: 20),

              // Totals
              _buildTotals(quote, showVatDetails, ttf, ttfBold),

              pw.Spacer(),

              // Footer Notes
              _buildFooterNotes(ttf),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildHeader(pw.SvgImage? logo, pw.Font font, pw.Font fontBold) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(companyName, style: pw.TextStyle(fontSize: 20, font: fontBold)),
            pw.Text(companyDesc, style: pw.TextStyle(fontSize: 12, font: font)),
            pw.SizedBox(height: 8),
            pw.Text(companyAddress, style: pw.TextStyle(fontSize: 9, font: font)),
            pw.Text(companyPhone, style: pw.TextStyle(fontSize: 9, font: font)),
            pw.Text(companyEmail, style: pw.TextStyle(fontSize: 9, font: font)),
          ],
        ),
        if (logo != null) logo,
      ],
    );
  }

  pw.Widget _buildCustomerInfo(Quote quote, pw.Font font, pw.Font fontBold) {
    final dateFormatter = DateFormat('dd.MM.yyyy');
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('FİYAT TEKLİFİ', style: pw.TextStyle(fontSize: 14, font: fontBold)),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Müşteri: ${quote.customerName}', style: pw.TextStyle(fontSize: 10, font: font)),
                  if (quote.representative.isNotEmpty)
                    pw.Text('Yetkili: ${quote.representative}', style: pw.TextStyle(fontSize: 10, font: font)),
                  if (quote.phone.isNotEmpty)
                    pw.Text('Telefon: ${quote.phone}', style: pw.TextStyle(fontSize: 10, font: font)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Tarih: ${dateFormatter.format(quote.createdAt.toLocal())}',
                      style: pw.TextStyle(fontSize: 10, font: font)),
                  if (quote.paymentTerm.isNotEmpty)
                    pw.Text('Ödeme: ${quote.paymentTerm}', style: pw.TextStyle(fontSize: 10, font: font)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildItemsTable(Quote quote, pw.Font font, pw.Font fontBold) {
    return pw.TableHelper.fromTextArray(
      context: null,
      headerStyle: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white),
      cellStyle: pw.TextStyle(font: font, fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
      cellHeight: 25,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.center,
        7: pw.Alignment.centerRight,
      },
      headers: ['Sıra', 'Ürün Adı', 'Miktar', 'Birim Fiyat', 'Tutar', 'KDV', 'KDV Tutarı', 'Toplam'],
      data: quote.items.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final item = entry.value;
        final totalWithVat = item.price * item.quantity * (1 + item.vatRate / 100);
        return [
          '$index',
          item.description,
          '${item.quantity} ${item.unit}',
          numberFormat.format(item.price),
          numberFormat.format(item.price * item.quantity),
          '%${item.vatRate.toStringAsFixed(0)}',
          numberFormat.format(item.price * item.quantity * item.vatRate / 100),
          numberFormat.format(totalWithVat),
        ];
      }).toList(),
    );
  }

  pw.Widget _buildItemsTableWithVatIncluded(Quote quote, pw.Font font, pw.Font fontBold) {
    return pw.TableHelper.fromTextArray(
      context: null,
      headerStyle: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white),
      cellStyle: pw.TextStyle(font: font, fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
      cellHeight: 25,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
      headers: ['Sıra', 'Ürün Adı', 'Miktar', 'Birim Fiyat (KDV Dahil)', 'Tutar', 'Toplam'],
      data: quote.items.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final item = entry.value;
        final unitPriceWithVat = item.price * (1 + item.vatRate / 100);
        final totalWithVat = unitPriceWithVat * item.quantity;
        return [
          '$index',
          item.description,
          '${item.quantity} ${item.unit}',
          numberFormat.format(unitPriceWithVat),
          numberFormat.format(item.price * item.quantity),
          numberFormat.format(totalWithVat),
        ];
      }).toList(),
    );
  }

  pw.Widget _buildTotals(Quote quote, bool showVatDetails, pw.Font font, pw.Font fontBold) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 250,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Column(
          children: [
            if (showVatDetails) ...[
              _buildTotalRow('Ara Toplam:', numberFormat.format(quote.totalAmount), font, fontBold),
              pw.SizedBox(height: 4),
              _buildTotalRow('KDV:', numberFormat.format(quote.vatAmount), font, fontBold),
              pw.SizedBox(height: 4),
              pw.Divider(color: PdfColors.grey600),
            ],
            _buildTotalRow(
              'GENEL TOPLAM:',
              numberFormat.format(quote.grandTotal),
              fontBold,
              fontBold,
              isGrandTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildTotalRow(String label, String value, pw.Font font, pw.Font fontBold,
      {bool isGrandTotal = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: isGrandTotal ? 11 : 10, font: fontBold)),
        pw.Text(value, style: pw.TextStyle(fontSize: isGrandTotal ? 11 : 10, font: font)),
      ],
    );
  }

  pw.Widget _buildFooterNotes(pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(
        fixedNote,
        style: pw.TextStyle(fontSize: 8, font: font, fontStyle: pw.FontStyle.italic),
      ),
    );
  }
}
