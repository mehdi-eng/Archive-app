import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class FullPdfPage extends StatelessWidget {
  final String url; // PDF network URL
  const FullPdfPage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    // Color palette
    const color1 = Color(0xFF7C4585); // AppBar
    const color2 = Color(0xFF9B7EBD); // Scroll head/status accent
    const color3 = Color(0xFFF49BAB); // Floating button / accent
    const color4 = Color(0xFFFFE1E0); // Background

    return Scaffold(
      backgroundColor: color4,
      appBar: AppBar(
        backgroundColor: color1,
        elevation: 6,
        title: const Text(
          "PDF Viewer",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      body: Container(
        color: color4, // Sets PDF background color
        child: SfPdfViewer.network(
          url,
          enableDoubleTapZooming: true,
          canShowScrollHead: true,
          canShowScrollStatus: true,
          pageLayoutMode: PdfPageLayoutMode.single,
          scrollDirection: PdfScrollDirection.vertical,
        ),
      ),
    );
  }
}
