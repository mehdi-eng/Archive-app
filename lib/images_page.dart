
import 'dart:async';
import 'dart:io';

import 'package:archive_app_new/pdf_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:camera/camera.dart';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';


import 'package:printing/printing.dart'; // For printing



class ImagesPage extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final String docId;
  
  final Map<String, dynamic> rowData;

  const ImagesPage({super.key, required this.images, required this.docId, required this.rowData});

  @override
  State<ImagesPage> createState() => _ImagesPageState();
}

class _ImagesPageState extends State<ImagesPage> {
  final ImagePicker _picker = ImagePicker();
  late List<Map<String, dynamic>> _images;

@override
  void initState() {
    super.initState();
    _images = List.from(widget.images);
    _loadAdditionalFiles();
  }


  String detectType(String ext, List<int> bytes) {
    if (bytes.length >= 4 && String.fromCharCodes(bytes.take(4)) == '%PDF') {
      return 'pdf';
    }
    // Detect image from header bytes
    if (bytes.length >= 4) {
      final header = bytes.take(4).toList();
      // JPEG: FF D8 FF E0 or FF D8 FF E1
      if (header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF) return 'image';
      // PNG: 89 50 4E 47
      if (header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47) return 'image';
    }
    // fallback to extension
    return ext == '.pdf' ? 'pdf' : 'image';
  }


Future<void> _loadAdditionalFiles() async {
  final data = widget.rowData;
  final category = data['category'] ?? '';
  final reference = data['reference'] ?? '';
  final paymentMethod = (data['paymentMethod'] ?? '').toString();

  final col = FirebaseFirestore.instance.collection('archives');

  try {
    // 1️⃣ Load main document images
    final query = await col
        .where('category', isEqualTo: category)
        .where('reference', isEqualTo: reference)
        .get();

    for (var doc in query.docs) {
      final docData = doc.data();
      if (docData['images'] != null) {
        final imagesList = (docData['images'] as List<dynamic>)
            .map((img) => img is Map<String, dynamic>
                ? {...img, 'source': 'Facture'}
                : {'url': img.toString(), 'name': 'file.pdf', 'source': 'Facture'})
            .toList();

        for (var img in imagesList) {
          await _addFileToImages(img);
        }
      }
    }

    // 2️⃣ Load "bons" (BC / BL) if any
    if (data['bons'] != null && data['bons'] is List) {
      final bons = List<String>.from(data['bons']);

      if (bons.isNotEmpty) {
        final bonQuery = await col
            .where('category', isEqualTo: category)
            .where('choice', whereIn: ['BC', 'BL'])
            .where('reference', whereIn: bons)
            .get();

        print('Bon documents found: ${bonQuery.docs.length}');

        for (var bonDoc in bonQuery.docs) {
          final bonData = bonDoc.data();
          if (bonData['images'] != null) {
            final bonImages = (bonData['images'] as List<dynamic>)
                .map((img) => img is Map<String, dynamic>
                    ? {...img, 'source': 'Bons'}
                    : {'url': img.toString(), 'name': 'bon.pdf', 'source': 'Bons'})
                .toList();

            for (var img in bonImages) {
              await _addFileToImages(img);
            }
          }
        }
      }
    }

    // 3️⃣ Load cheque images if payment method contains CHEQUE
    if (paymentMethod.toUpperCase().contains('CHEQUE')) {
      final chequeQuery = await col
          .where('category', isEqualTo: category)
          .where('reference', isEqualTo: reference)
          .where('num_cheque', isNotEqualTo: null)
          .get();

      for (var chequeDoc in chequeQuery.docs) {
        final chequeData = chequeDoc.data();
        if (chequeData['cheque_image'] != null) {
  final chequeImgData = chequeData['cheque_image'];

  List<Map<String, dynamic>> chequeImages = [];
  if (chequeImgData is String) {
    chequeImages.add({'url': chequeImgData, 'name': 'cheque.pdf', 'source': 'Cheque'});
  } else if (chequeImgData is List) {
    chequeImages = chequeImgData
        .map((img) => img is Map<String, dynamic>
            ? {...img, 'source': 'Cheque'}
            : {'url': img.toString(), 'name': 'cheque.pdf', 'source': 'Cheque'})
        .toList();
  }

  for (var img in chequeImages) {
    await _addFileToImages(img);
  }
}

      }
    }

    // Remove duplicates
    final uniqueImages = {for (var img in _images) img['url']: img}.values.toList();
    setState(() => _images = uniqueImages);

    // Debug print all loaded URLs
    print('--- All loaded files ---');
    for (var img in _images) {
      print('File URL: ${img['url']} | Name: ${img['name']} | Type: ${img['type']} | Source: ${img['source']}');
    }
    print('------------------------');

  } catch (e) {
    debugPrint('Failed to load additional files: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to load files: $e')),
    );
  }
}


// Helper to fetch bytes and detect type
Future<void> _addFileToImages(Map<String, dynamic> img) async {
  final url = img['url'] ?? '';
  final name = img['name'] ?? 'file.pdf';
  final ext = p.extension(name).toLowerCase();


  if (url.isEmpty) return;

  try {
    final response = await http.get(Uri.parse(url));
    final bytes = response.bodyBytes;

    if (bytes.isEmpty) return;

    final type = detectType(ext, bytes);




    setState(() {
      _images.add({'url': url, 'name': name, 'type': type, 'source': img['source'] ?? ''});
    });


    debugPrint('Loaded file | Extension: $ext | Type: $type | Length: ${bytes.length}');
  } catch (e) {
    debugPrint('Failed to load file | Extension: $ext | Error: $e');
  }
}



Future<File> _compressFile(File file) async {
  final path = '${file.parent.path}/compressed_${p.basename(file.path)}';

  try {
    // Compress the file
    final result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      path,
      quality: 85,
    ) as File?; // Explicit cast to File?

    // Return compressed file or fallback to original
    return result ?? file;
  } catch (e) {
    // If any error occurs, fallback to original
    debugPrint('Compression failed: $e');
    return file;
  }
}



Future<List<XFile>?> scanDocuments(BuildContext context) async {
  try {
    final result = await FlutterDocScanner().getScanDocuments(); // no maxPages
    print('Scanner result: ############################################## $result');

    if (result != null) {
      final List<XFile> scannedFiles = [];

      // Check if result is Map with pdfUri
      if (result is Map && result['pdfUri'] != null) {
        final uri = result['pdfUri'] as String;
        final path = uri.replaceFirst('file://', ''); // remove file://
        final file = XFile(path);
        scannedFiles.add(file);
      }
      // If result is a List of paths, handle them too
      else if (result is List) {
        scannedFiles.addAll(result.map((path) => XFile(path.toString())));
      }

      // Debug
      print('Debug: scannedFiles contains:');
      for (var f in scannedFiles) {
        print(f.path);
      }

      return scannedFiles;
    } else {
      print('Debug: No files returned from scanner.');
      return [];
    }
  } on PlatformException catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e')));
    return null;
  }
}

Future<void> _scanAndUploadDocument() async {
  final scannedFiles = await scanDocuments(context);
  if (scannedFiles == null || scannedFiles.isEmpty) return;

  for (var xfile in scannedFiles) {
    final originalFile = File(xfile.path);
    final fileName = p.basename(originalFile.path);

    // Compress the file
    final file = await _compressFile(originalFile);

    try {
      // Upload to Firebase Storage
      final storageRef =
          FirebaseStorage.instance.ref('archives/${widget.docId}/$fileName');
      await storageRef.putFile(file);
      final url = await storageRef.getDownloadURL();

      final newImage = {'url': url, 'name': fileName};

      // Update Firestore document
      final docRef =
          FirebaseFirestore.instance.collection('archives').doc(widget.docId);
      await docRef.update({
        'images': FieldValue.arrayUnion([newImage])
      });

      setState(() {
        _images.add(newImage);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$fileName uploaded successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload $fileName: $e')),
      );
    }
  }
}



  @override
  Widget build(BuildContext context) {
    const color1 = Color(0xFF7C4585);
    const color2 = Color(0xFF9B7EBD);
    const color3 = Color(0xFFF49BAB);
    const color4 = Color(0xFFFFE1E0);

    return Scaffold(
      backgroundColor: color4,
      appBar: AppBar(
        title: const Text('Images'),
        titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
        backgroundColor: color1,
        iconTheme: const IconThemeData(
        color: Colors.white, // ← makes back arrow white
      ),
        elevation: 6,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: _images.isEmpty
          ? Center(
              child: Text(
                'No images',
                style: TextStyle(
                  fontSize: 18,
                  color: color2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _images.length,

  itemBuilder: (context, index) {
  final url = _images[index]['url'] ?? '';
  final name = _images[index]['name'] ?? '';
  final ext = p.extension(name).toLowerCase();

  debugPrint('File URL [$index]: $url');


  if (url.isEmpty) {
    setState(() {
      _images.removeAt(index);
    });
    return const SizedBox.shrink();
  }



Future<String?> getFileMimeType(String url) async {
  try {
    final response = await http.head(Uri.parse(url));
    if (response.statusCode == 200) {
      return response.headers['content-type']; // e.g., "application/pdf" or "image/png"
    }
  } catch (e) {
    debugPrint('Failed to get MIME type for $url: $e');
  }
  return null;
}



final double previewHeight = 450;

final fileTypeFuture = getFileMimeType(url);


Widget fileWidget = FutureBuilder<String?>(
  future: getFileMimeType(url),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: Text("Loading file..."));
    }

    final mime = snapshot.data ?? '';
    if (mime.contains('pdf')) {
      // PDF preview
      return SizedBox(
        height: previewHeight,
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => FullPdfPage(url: url)),
            );
          },
          child: PdfPreview(
            build: (format) async {
              final bytes = await http.get(Uri.parse(url)).then((r) => r.bodyBytes);
              return bytes;
            },
            canChangePageFormat: false,
            canChangeOrientation: false,
            actions: [],
            useActions: false,
          ),
        ),
      );
    } else if (mime.startsWith('image/')) {
      // Image preview
      return SizedBox(
        height: previewHeight,
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: Text(name)),
                  body: Center(child: Image.network(url, fit: BoxFit.contain)),
                ),
              ),
            );
          },
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),
        ),
      );
    } else {
      return const Center(
        child: Text("Unsupported file type", style: TextStyle(color: Colors.red)),
      );
    }
  },
);







return Card(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  ),
  elevation: 4,
  shadowColor: color2.withOpacity(0.4),
  margin: const EdgeInsets.only(bottom: 20),
  child: Padding(
    padding: const EdgeInsets.all(12),

child: Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    // ✅ Show source label
    Text(
      _images[index]['source'] ?? '',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.grey[700],
      ),
    ),
    const SizedBox(height: 8),

    // Your file preview (image or PDF)
    fileWidget,
    const SizedBox(height: 12),

    // Buttons row (Share, Print, Delete)
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Share Button
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: color1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () async {
              try {
                final response = await http.get(Uri.parse(url));
                final bytes = response.bodyBytes;

                final dir = await getTemporaryDirectory();
                final file = File('${dir.path}/$name');
                await file.writeAsBytes(bytes);

                await Share.shareXFiles(
                  [XFile(file.path)],
                  text: 'Check this file!',
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to share: $e')),
                );
              }
            },
            icon: const Icon(Icons.share, color: Colors.white),
            label: const Text(
              'Share',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Print Button
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: color3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () async {
              try {
                final response = await http.get(Uri.parse(url));
                final bytes = response.bodyBytes;
                if (bytes.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('File is empty or cannot be loaded')),
                  );
                  return;
                }

                final fileType = detectType(p.extension(name).toLowerCase(), bytes);

                await Printing.layoutPdf(
                  onLayout: (format) async {
                    if (fileType == 'pdf') {
                      return bytes;
                    } else if (fileType == 'image') {
                      final doc = pw.Document();
                      final image = pw.MemoryImage(bytes);
                      doc.addPage(pw.Page(
                        pageFormat: format,
                        build: (context) => pw.Center(child: pw.Image(image)),
                      ));
                      return doc.save();
                    } else {
                      return pw.Document().save();
                    }
                  },
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to print: $e')),
                );
              }
            },
            icon: const Icon(Icons.print, color: Colors.white),
            label: const Text(
              'Print',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Delete Button
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Confirm Delete'),
                  content: const Text('Are you sure you want to delete this file?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm != true) return;

              try {
                final storageRef = FirebaseStorage.instance.refFromURL(url);
                await storageRef.delete();

                final docRef = FirebaseFirestore.instance
                    .collection('archives')
                    .doc(widget.docId);
                await docRef.update({
                  'images': FieldValue.arrayRemove([{'url': url, 'name': name}])
                });

                setState(() {
                  _images.removeAt(index);
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('File deleted successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete: $e')),
                );
              }
            },
            icon: const Icon(Icons.delete, color: Colors.white),
            label: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  ],
),

  
  ),
);




}



           
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: color3,
        onPressed: _scanAndUploadDocument,
        child: const Icon(Icons.add),
      ),
    );
  }
}

