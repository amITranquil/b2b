// lib/services/pdf_export_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/quote.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/services/i_pdf_service.dart';
import '../screens/pdf_preview_screen.dart';

class PdfExportService implements IPdfService {
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

  /// Uygulama içi PDF önizleme (Syncfusion PDF Viewer)
  @override
  Future<void> previewQuote(material.BuildContext context, Quote quote) async {
    final pdfDoc = await _generatePdfDocument(quote);
    final pdfBytes = await pdfDoc.save();

    if (context.mounted) {
      await material.Navigator.push(
        context,
        material.MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(
            pdfBytes: pdfBytes,
            title: 'Teklif Önizleme - ${quote.customerName}',
            showSaveButton: true,
          ),
        ),
      );
    }
  }

  /// Eski yöntem: Printing paketi ile önizleme
  Future<void> previewQuoteWithPrinting(
      material.BuildContext context, Quote quote) async {
    final pdfDoc = await _generatePdfDocument(quote);

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfDoc.save(),
      name:
          'teklif_${quote.customerName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  @override
  Future<String?> exportQuote(Quote quote) async {
    final pdfDoc = await _generatePdfDocument(quote);
    final fileName =
        'teklif_${quote.customerName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

    // Android için özel davranış
    if (Platform.isAndroid) {
      try {
        // Temporary directory'ye kaydet
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/$fileName';
        final file = File(filePath);

        await file.writeAsBytes(await pdfDoc.save());

        // Share ile paylaş (kullanıcı kaydetme konumunu seçebilir)
        final result = await Share.shareXFiles(
          [XFile(filePath, mimeType: 'application/pdf')],
          subject: 'Teklif - ${quote.customerName}',
          text: 'Teklif PDF dosyası',
        );

        if (kDebugMode) {
          print('Share result: ${result.status}');
        }

        return filePath;
      } catch (e) {
        throw Exception('PDF kaydetme hatası: $e');
      }
    }

    // Desktop (Windows, macOS, Linux) için FilePicker
    String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'PDF Kaydetme Konumunu Seçin',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    // Kullanıcı iptal ettiyse null döner
    if (outputPath == null) {
      if (kDebugMode) {
        print('PDF kaydetme işlemi iptal edildi');
      }
      return null;
    }

    // Eğer extension eklenmemişse ekle
    if (!outputPath.toLowerCase().endsWith('.pdf')) {
      outputPath = '$outputPath.pdf';
    }

    final file = File(outputPath);

    try {
      await file.writeAsBytes(await pdfDoc.save());
      return outputPath;
    } catch (e) {
      throw Exception('PDF kaydetme hatası: $e');
    }
  }

  Future<pw.Document> _generatePdfDocument(Quote quote) async {
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

    // SVG logo yüklemesi
    pw.SvgImage? svgLogo;
    try {
      final logoSources = ['assets/logo.svg', '../assets/logo.svg', 'logo.svg'];

      for (var path in logoSources) {
        try {
          final logoData = await rootBundle.loadString(path);
          svgLogo = pw.SvgImage(svg: logoData, width: 64, height: 64);
          break; // Başarılı yükleme sonrası döngüden çık
        } catch (e) {
          if (kDebugMode) {
            print('Failed to load logo from $path: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('SVG logo loading failed: $e');
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          _buildHeader(boldFont!, regularFont!, svgLogo),
          pw.SizedBox(height: 20),
          _buildCustomerInfo(quote, regularFont, boldFont),
          pw.SizedBox(height: 20),
          _buildItemsTable(quote, regularFont, boldFont),
          pw.SizedBox(height: 20),
          _buildTotals(quote, regularFont, boldFont),
          if (quote.extraNote != null && quote.extraNote!.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _buildNote(quote.extraNote!, regularFont),
          ],
          pw.SizedBox(height: 40),
          _buildSignatureArea(regularFont),
          pw.SizedBox(height: 20),
          _buildFooterTimestamps(quote, regularFont),
          pw.SizedBox(height: 20),
          _buildFixedNote(regularFont),
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _buildHeader(
      pw.Font boldFont, pw.Font regularFont, pw.SvgImage? svgLogo) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // Sol taraf - Şirket bilgileri
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  companyName,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 14,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  companyDesc,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 12,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  companyAddress,
                  style: pw.TextStyle(fontSize: 9, font: regularFont),
                ),
                pw.Text(
                  'Tel: $companyPhone',
                  style: pw.TextStyle(fontSize: 9, font: regularFont),
                ),
                pw.Text(
                  'E-posta: $companyEmail',
                  style: pw.TextStyle(fontSize: 9, font: regularFont),
                ),
                pw.Text(
                  'Web: $companyWebsite',
                  style: pw.TextStyle(fontSize: 9, font: regularFont),
                ),
              ],
            ),
            // Orta - Logo
            if (svgLogo != null)
              pw.Container(
                width: 80,
                height: 80,
                child: svgLogo,
              ),
            // Sağ taraf - Form başlığı
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'MÜŞTERİ TEKLİF VE SİPARİŞ FORMU',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 10,
                  ),
                  textAlign: pw.TextAlign.end,
                ),
              ],
            ),
          ],
        ),
        pw.Divider(thickness: 1),
      ],
    );
  }

  pw.Widget _buildCustomerInfo(
      Quote quote, pw.Font regularFont, pw.Font boldFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildInfoRow(
            'Müşteri Adı:', quote.customerName, regularFont, boldFont),
        _buildInfoRow(
            'Firma Yetkilisi:', quote.representative, regularFont, boldFont),
        _buildInfoRow('Telefon:', quote.phone, regularFont, boldFont),
        _buildInfoRow('Ödeme Şekli:', quote.paymentTerm, regularFont, boldFont),
        _buildInfoRow(
          'Tarih:',
          DateFormat('dd.MM.yyyy').format(quote.createdAt),
          regularFont,
          boldFont,
        ),
      ],
    );
  }

  pw.Widget _buildInfoRow(
    String label,
    String value,
    pw.Font regularFont,
    pw.Font boldFont,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(font: boldFont, fontSize: 10),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: regularFont, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildItemsTable(
      Quote quote, pw.Font regularFont, pw.Font boldFont) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.7),
        1: const pw.FlexColumnWidth(5),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(2),
        5: const pw.FlexColumnWidth(1.5),
        6: const pw.FlexColumnWidth(1.5),
        7: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
          ),
          children: [
            'No',
            'Malzeme ve İşçilik Listesi',
            'Miktar',
            'Birim',
            'Br.Fiyatı',
            'Tutar',
            'KDV',
            'KDV Tutarı',
          ]
              .map((text) => pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      text,
                      style: pw.TextStyle(font: boldFont, fontSize: 9),
                      textAlign: pw.TextAlign.center,
                    ),
                  ))
              .toList(),
        ),
        ...quote.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final itemSubtotal = item.quantity * item.price;
          final itemVat = itemSubtotal * (item.vatRate / 100);

          return pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  (index + 1).toString(),
                  style: pw.TextStyle(font: regularFont, fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  item.description,
                  style: pw.TextStyle(font: regularFont, fontSize: 9),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  item.quantity.toString(),
                  style: pw.TextStyle(font: regularFont, fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  item.unit,
                  style: pw.TextStyle(font: regularFont, fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  numberFormat.format(item.price),
                  style: pw.TextStyle(font: regularFont, fontSize: 9),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  numberFormat.format(itemSubtotal),
                  style: pw.TextStyle(font: regularFont, fontSize: 9),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  '%${item.vatRate.toInt()}',
                  style: pw.TextStyle(font: regularFont, fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  numberFormat.format(itemVat),
                  style: pw.TextStyle(font: regularFont, fontSize: 9),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildTotals(Quote quote, pw.Font regularFont, pw.Font boldFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        _buildTotalRow(
            'Toplam Tutar:', quote.totalAmount, regularFont, boldFont),
        _buildTotalRow('KDV:', quote.vatAmount, regularFont, boldFont),
        pw.Divider(thickness: 1),
        _buildTotalRow(
          'Genel Toplam:',
          quote.totalAmount + quote.vatAmount,
          regularFont,
          boldFont,
          isTotal: true,
        ),
      ],
    );
  }

  pw.Widget _buildTotalRow(
    String label,
    double value,
    pw.Font regularFont,
    pw.Font boldFont, {
    bool isTotal = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: isTotal ? boldFont : regularFont,
              fontSize: isTotal ? 10 : 9,
            ),
          ),
          pw.SizedBox(width: 10),
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              numberFormat.format(value),
              style: pw.TextStyle(
                font: isTotal ? boldFont : regularFont,
                fontSize: isTotal ? 10 : 9,
              ),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildNote(String note, pw.Font regularFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'AÇIKLAMA:',
          style: pw.TextStyle(
            font: regularFont,
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          note,
          style: pw.TextStyle(font: regularFont, fontSize: 9),
        ),
      ],
    );
  }

  pw.Widget _buildFixedNote(pw.Font regularFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'NOT:',
          style: pw.TextStyle(
            font: regularFont,
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          fixedNote,
          style: pw.TextStyle(font: regularFont, fontSize: 8),
        ),
      ],
    );
  }

  pw.Widget _buildSignatureArea(pw.Font regularFont) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Sol taraf - Teklif Veren
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Siparişi Alan / Teklif Veren',
                style: pw.TextStyle(font: regularFont, fontSize: 9),
              ),
              pw.SizedBox(height: 30),
              pw.Text('Adı-Soyadı:',
                  style: pw.TextStyle(font: regularFont, fontSize: 9)),
              pw.SizedBox(height: 8),
              pw.Text('İmza:',
                  style: pw.TextStyle(font: regularFont, fontSize: 9)),
              pw.SizedBox(height: 8),
              pw.Text('Kaşe:',
                  style: pw.TextStyle(font: regularFont, fontSize: 9)),
            ],
          ),
        ),
        // Sağ taraf - Müşteri Onayı (Genel Toplam ile aynı hizada, sola yaslanmış)
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Müşteri Onayı',
                style: pw.TextStyle(font: regularFont, fontSize: 9)),
            pw.SizedBox(height: 30),
            pw.SizedBox(
              width: 100, // Totals ile aynı genişlik
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Adı-Soyadı:',
                      style: pw.TextStyle(font: regularFont, fontSize: 9)),
                  pw.SizedBox(height: 8),
                  pw.Text('İmza:',
                      style: pw.TextStyle(font: regularFont, fontSize: 9)),
                  pw.SizedBox(height: 8),
                  pw.Text('Kaşe:',
                      style: pw.TextStyle(font: regularFont, fontSize: 9)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildFooterTimestamps(Quote quote, pw.Font regularFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Oluşturma Tarihi: ${DateFormat('dd.MM.yyyy HH:mm').format(quote.createdAt)}',
          style: pw.TextStyle(font: regularFont, fontSize: 7),
        ),
        if (quote.modifiedAt != null)
          pw.Text(
            'Son Güncelleme: ${DateFormat('dd.MM.yyyy HH:mm').format(quote.modifiedAt!)}',
            style: pw.TextStyle(font: regularFont, fontSize: 7),
          ),
      ],
    );
  }

  // ========== KDV Dahil (KDV Gizli) Versiyonlar ==========

  /// Uygulama içi PDF önizleme (KDV dahil - Syncfusion PDF Viewer)
  @override
  Future<void> previewQuoteWithVatIncluded(
      material.BuildContext context, Quote quote) async {
    final pdfDoc = await _generatePdfDocumentWithVatIncluded(quote);
    final pdfBytes = await pdfDoc.save();

    if (context.mounted) {
      await material.Navigator.push(
        context,
        material.MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(
            pdfBytes: pdfBytes,
            title: 'Teklif Önizleme (KDV Dahil) - ${quote.customerName}',
            showSaveButton: true,
          ),
        ),
      );
    }
  }

  /// Eski yöntem: Printing paketi ile önizleme (KDV dahil)
  Future<void> previewQuoteWithVatIncludedPrinting(
      material.BuildContext context, Quote quote) async {
    final pdfDoc = await _generatePdfDocumentWithVatIncluded(quote);

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfDoc.save(),
      name:
          'teklif_${quote.customerName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  @override
  Future<String?> exportQuoteWithVatIncluded(Quote quote) async {
    final pdfDoc = await _generatePdfDocumentWithVatIncluded(quote);
    final fileName =
        'teklif_${quote.customerName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

    // Android için özel davranış
    if (Platform.isAndroid) {
      try {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/$fileName';
        final file = File(filePath);

        await file.writeAsBytes(await pdfDoc.save());

        final result = await Share.shareXFiles(
          [XFile(filePath, mimeType: 'application/pdf')],
          subject: 'Teklif (KDV Dahil) - ${quote.customerName}',
          text: 'Teklif PDF dosyası (KDV Dahil)',
        );

        if (kDebugMode) {
          print('Share result: ${result.status}');
        }

        return filePath;
      } catch (e) {
        throw Exception('PDF kaydetme hatası: $e');
      }
    }

    // Desktop için FilePicker
    String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'PDF Kaydetme Konumunu Seçin',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (outputPath == null) {
      if (kDebugMode) {
        print('PDF kaydetme işlemi iptal edildi');
      }
      return null;
    }

    if (!outputPath.toLowerCase().endsWith('.pdf')) {
      outputPath = '$outputPath.pdf';
    }

    final file = File(outputPath);

    try {
      await file.writeAsBytes(await pdfDoc.save());
      return outputPath;
    } catch (e) {
      throw Exception('PDF kaydetme hatası: $e');
    }
  }

  Future<pw.Document> _generatePdfDocumentWithVatIncluded(Quote quote) async {
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

    pw.SvgImage? svgLogo;
    try {
      final logoSources = ['assets/logo.svg', '../assets/logo.svg', 'logo.svg'];
      for (final path in logoSources) {
        try {
          final svgString = await rootBundle.loadString(path);
          svgLogo = pw.SvgImage(svg: svgString);
          break;
        } catch (e) {
          continue;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Logo yüklenemedi: $e');
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => [
          _buildHeader(boldFont!, regularFont!, svgLogo),
          pw.SizedBox(height: 20),
          _buildCustomerInfo(quote, regularFont, boldFont),
          pw.SizedBox(height: 20),
          _buildItemsTableWithVatIncluded(quote, regularFont, boldFont),
          pw.SizedBox(height: 20),
          _buildTotalsWithVatIncluded(quote, regularFont, boldFont),
          if (quote.extraNote != null && quote.extraNote!.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _buildNote(quote.extraNote!, regularFont),
          ],
          pw.SizedBox(height: 40),
          _buildSignatureArea(regularFont),
          pw.SizedBox(height: 20),
          _buildFooterTimestamps(quote, regularFont),
          pw.SizedBox(height: 20),
          _buildFixedNote(regularFont),
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _buildItemsTableWithVatIncluded(
      Quote quote, pw.Font regularFont, pw.Font boldFont) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.7),
        1: const pw.FlexColumnWidth(6),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(2.5),
        5: const pw.FlexColumnWidth(2.5),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
          ),
          children: [
            'No',
            'Malzeme ve İşçilik Listesi',
            'Miktar',
            'Birim',
            'Birim Fiyatı',
            'Tutar',
          ]
              .map((text) => pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      text,
                      style: pw.TextStyle(font: boldFont, fontSize: 9),
                      textAlign: pw.TextAlign.center,
                    ),
                  ))
              .toList(),
        ),
        ...quote.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;

          // KDV dahil fiyatları hesapla
          final priceWithVat = item.price * (1 + item.vatRate / 100);
          final totalWithVat = item.quantity * priceWithVat;

          return pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  (index + 1).toString(),
                  style: pw.TextStyle(font: regularFont, fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  item.description,
                  style: pw.TextStyle(font: regularFont, fontSize: 9),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  item.quantity.toString(),
                  style: pw.TextStyle(font: regularFont, fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  item.unit,
                  style: pw.TextStyle(font: regularFont, fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  numberFormat.format(priceWithVat),
                  style: pw.TextStyle(font: regularFont, fontSize: 9),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  numberFormat.format(totalWithVat),
                  style: pw.TextStyle(font: regularFont, fontSize: 9),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildTotalsWithVatIncluded(
      Quote quote, pw.Font regularFont, pw.Font boldFont) {
    final grandTotal = quote.totalAmount + quote.vatAmount;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                'TOPLAM:',
                style: pw.TextStyle(font: boldFont, fontSize: 14),
              ),
              pw.SizedBox(width: 20),
              pw.Container(
                width: 150,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  border: pw.Border.all(width: 1),
                ),
                child: pw.Text(
                  numberFormat.format(grandTotal),
                  style: pw.TextStyle(font: boldFont, fontSize: 14),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
