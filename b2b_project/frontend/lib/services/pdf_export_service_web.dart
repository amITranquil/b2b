// ignore_for_file: avoid_web_libraries_in_flutter

import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/quote.dart';
import 'pdf_export_service.dart';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'package:file_picker/file_picker.dart';

PdfExportService createPdfExportService() => PdfExportServiceWeb();

class PdfExportServiceWeb implements PdfExportService {
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

  /// PDF indir - file dialog ile konum seçtir
  @override
  Future<bool> downloadPdf(Quote quote, bool showVatDetails) async {
    final pdfDoc = await _generatePdfDocument(quote, showVatDetails);
    final bytes = await pdfDoc.save();

    if (kIsWeb) {
      final fileName =
          'teklif_${quote.customerName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(quote.createdAt)}.pdf';

      // Önce FilePicker dene (bytes olmadan, sadece path alacak)
      try {
        final path = await FilePicker.platform.saveFile(
          dialogTitle: 'PDF\'i Kaydet',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );

        // Kullanıcı vazgeçti
        if (path == null) {
          if (kDebugMode) {
            print('Kullanıcı kaydetme işlemini iptal etti (FilePicker)');
          }
          return false;
        }

        // FilePicker başarılı, şimdi native API ile kaydet
        try {
          final result = await _showSaveFilePickerPolyfill(bytes, fileName);
          return result;
        } catch (e2) {
          // Kullanıcı native API'de vazgeçti
          if (e2.toString().contains('AbortError') || e2.toString().contains('aborted')) {
            if (kDebugMode) {
              print('Kullanıcı kaydetme işlemini iptal etti (native API)');
            }
            return false;
          }
          rethrow;
        }
      } catch (e) {
        // FilePicker çalışmadı, direkt native API dene
        if (kDebugMode) {
          print('FilePicker desteklenmiyor, native API deneniyor: $e');
        }

        try {
          final result = await _showSaveFilePickerPolyfill(bytes, fileName);
          return result;
        } catch (e2) {
          // Kullanıcı iptal ettiyse (AbortError), false döndür
          if (e2.toString().contains('AbortError') || e2.toString().contains('aborted')) {
            if (kDebugMode) {
              print('Kullanıcı kaydetme işlemini iptal etti (polyfill)');
            }
            return false;
          }

          // showSaveFilePicker API yoksa otomatik indirme yap
          if (kDebugMode) {
            print('Native API desteklenmiyor, otomatik indirme yapılıyor: $e2');
          }

          // Son çare: Otomatik indirme (download attribute)
          final blob = html.Blob([bytes], 'application/pdf');
          final url = html.Url.createObjectUrlFromBlob(blob);

          html.AnchorElement(href: url)
            ..setAttribute('download', fileName)
            ..click();

          Future.delayed(const Duration(milliseconds: 100), () {
            html.Url.revokeObjectUrl(url);
          });

          return true;
        }
      }
    }
    return false;
  }

  /// Native showSaveFilePicker API kullan (Brave, Chrome, Edge için)
  Future<bool> _showSaveFilePickerPolyfill(List<int> bytes, String fileName) async {
    try {
      // showSaveFilePicker API'sinin varlığını kontrol et
      if (!js.context.hasProperty('showSaveFilePicker')) {
        throw Exception('showSaveFilePicker API mevcut değil');
      }

      // Options object oluştur
      final options = js_util.jsify({
        'suggestedName': fileName,
        'types': [
          {
            'description': 'PDF Dosyası',
            'accept': {
              'application/pdf': ['.pdf']
            }
          }
        ]
      });

      // showSaveFilePicker çağır
      final fileHandlePromise = js_util.callMethod(
        html.window,
        'showSaveFilePicker',
        [options],
      );

      // Promise'i await et
      final fileHandle = await js_util.promiseToFuture(fileHandlePromise);

      // Writable stream oluştur
      final writablePromise = js_util.callMethod(fileHandle, 'createWritable', []);
      final writable = await js_util.promiseToFuture(writablePromise);

      // PDF bytes'ı yaz
      final uint8List = Uint8List.fromList(bytes);
      final writePromise = js_util.callMethod(writable, 'write', [uint8List]);
      await js_util.promiseToFuture(writePromise);

      // Stream'i kapat
      final closePromise = js_util.callMethod(writable, 'close', []);
      await js_util.promiseToFuture(closePromise);

      if (kDebugMode) {
        print('Dosya başarıyla kaydedildi (native API)');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Native showSaveFilePicker hatası: $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> printPdf(Quote quote, bool showVatDetails) async {
    final pdfDoc = await _generatePdfDocument(quote, showVatDetails);
    final bytes = await pdfDoc.save();

    // Web'de browser'ın print dialog'unu kullan
    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);

      // Yeni pencerede aç
      final printWindow = html.window.open(url, '_blank');

      // Pencere yüklendikten sonra print dialog'u aç
      Future.delayed(const Duration(milliseconds: 1000), () {
        try {
          js_util.callMethod(printWindow, 'print', []);
          // Print dialog kapatıldıktan sonra pencereyi kapat
          Future.delayed(const Duration(milliseconds: 500), () {
            printWindow.close();
          });
        } catch (e) {
          if (kDebugMode) {
            print('Print hatası: $e');
          }
        }
      });

      // URL'i temizle
      Future.delayed(const Duration(seconds: 3), () {
        html.Url.revokeObjectUrl(url);
      });
    }
  }

  Future<pw.Document> _generatePdfDocument(
      Quote quote, bool showVatDetails) async {
    pw.Font? regularFont;
    pw.Font? boldFont;

    // Font yükleme - Google Fonts ile (Türkçe karakter desteği için)
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

    // SVG logo yüklemesi (b2b_manager ile aynı)
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
        margin: showVatDetails ? const pw.EdgeInsets.all(32) : const pw.EdgeInsets.all(20),
        build: (pw.Context context) => [
          _buildHeader(boldFont!, regularFont!, svgLogo),
          pw.SizedBox(height: 20),
          _buildCustomerInfo(quote, regularFont, boldFont),
          pw.SizedBox(height: 20),
          showVatDetails
              ? _buildItemsTable(quote, regularFont, boldFont)
              : _buildItemsTableWithVatIncluded(quote, regularFont, boldFont),
          pw.SizedBox(height: 20),
          showVatDetails
              ? _buildTotals(quote, regularFont, boldFont)
              : _buildTotalsWithVatIncluded(quote, regularFont, boldFont),
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

  // KDV Detaylı - Normal tablo (b2b_manager ile aynı - 8 kolon)
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
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
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

  // KDV Gizli - Fiyatlar KDV dahil gösterilir
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
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
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

  // KDV Detaylı - Ara toplam + KDV + Genel toplam (b2b_manager ile aynı)
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

  // KDV Gizli - Sadece toplam
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

  pw.Widget _buildSignatureArea(pw.Font regularFont) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Sol taraf - Teklif Veren (b2b_manager ile aynı)
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
}
