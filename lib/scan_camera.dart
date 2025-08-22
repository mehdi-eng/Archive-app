import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:flutter/services.dart';



class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key}); // no pickedFiles here

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  List<XFile> _picked = []; // store scanned images here

  Future<void> scanDocument() async {
    try {
      final result = await FlutterDocScanner().getScanDocuments(page: 3);

      if (result != null && result is List) {
        List<XFile> scannedFiles =
            result.map((path) => XFile(path.toString())).toList();

        setState(() {
          _picked.addAll(scannedFiles);
        });
      }
    } on PlatformException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Scan failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Document Scanner')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: scanDocument,
            child: const Text("Scan Document"),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _picked.isEmpty
                ? const Center(child: Text('No scanned documents'))
                : PhotoViewGallery.builder(
                    itemCount: _picked.length,
                    builder: (context, index) {
                      return PhotoViewGalleryPageOptions(
                        imageProvider: FileImage(File(_picked[index].path)),
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 2,
                      );
                    },
                    scrollPhysics: const BouncingScrollPhysics(),
                    backgroundDecoration:
                        const BoxDecoration(color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }
}
