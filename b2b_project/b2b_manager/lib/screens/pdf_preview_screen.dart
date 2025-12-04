import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

/// PDF önizleme ekranı - Syncfusion PDF Viewer ile
class PdfPreviewScreen extends StatefulWidget {
  final Uint8List pdfBytes;
  final String title;
  final bool showSaveButton;

  const PdfPreviewScreen({
    super.key,
    required this.pdfBytes,
    this.title = 'PDF Önizleme',
    this.showSaveButton = true,
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  bool _isLoading = false;

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  Future<void> _savePdf() async {
    try {
      setState(() => _isLoading = true);

      // Kullanıcıdan kaydetme konumu seç
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'PDF\'i Kaydet',
        fileName: 'teklif_${DateTime.now().millisecondsSinceEpoch}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputPath != null) {
        // Eğer kullanıcı .pdf uzantısı eklemediyse ekle
        if (!outputPath.toLowerCase().endsWith('.pdf')) {
          outputPath += '.pdf';
        }

        // PDF'i dosyaya yaz
        final file = File(outputPath);
        await file.writeAsBytes(widget.pdfBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF başarıyla kaydedildi: $outputPath'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF kaydetme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sharePdf() async {
    try {
      setState(() => _isLoading = true);

      // Geçici dizine kaydet
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/teklif_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await tempFile.writeAsBytes(widget.pdfBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF geçici dosyaya kaydedildi: ${tempFile.path}'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF paylaşma hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _zoomIn() {
    _pdfViewerController.zoomLevel += 0.25;
  }

  void _zoomOut() {
    if (_pdfViewerController.zoomLevel > 1.0) {
      _pdfViewerController.zoomLevel -= 0.25;
    }
  }

  void _resetZoom() {
    _pdfViewerController.zoomLevel = 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          // Zoom kontrolleri
          IconButton(
            icon: const Icon(Icons.zoom_out),
            tooltip: 'Uzaklaştır',
            onPressed: _zoomOut,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            tooltip: 'Yakınlaştır',
            onPressed: _zoomIn,
          ),
          IconButton(
            icon: const Icon(Icons.fit_screen),
            tooltip: 'Sıfırla',
            onPressed: _resetZoom,
          ),
          // Kaydet butonu
          if (widget.showSaveButton)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'PDF Kaydet',
              onPressed: _isLoading ? null : _savePdf,
            ),
          // Paylaş butonu
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Paylaş',
            onPressed: _isLoading ? null : _sharePdf,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SfPdfViewer.memory(
              widget.pdfBytes,
              controller: _pdfViewerController,
              canShowScrollHead: true,
              canShowScrollStatus: true,
              enableDoubleTapZooming: true,
              enableTextSelection: true,
            ),
    );
  }
}
