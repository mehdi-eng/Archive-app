import 'dart:io';

import 'package:archive_app_new/camera_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:camera/camera.dart';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';




class InsertPage extends StatefulWidget {
  const InsertPage({super.key, required this.categoryTitle});
  final String categoryTitle;

  @override
  State<InsertPage> createState() => _InsertPageState();
}



class _InsertPageState extends State<InsertPage> {
  final _formKey = GlobalKey<FormState>();
  final _refCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _amountCtrl = TextEditingController();

final TextEditingController _clientCtrl = TextEditingController();


  bool _hibta = false;
  bool _itri = false;

  bool _paid = false;
  bool _not_paid = false;

  bool _cheque = false;
  bool _virement = false;
  bool _espece = false;
  bool _effet = false;

  String? selectedOptionPay;
  String? selectedOptionPayMethod;
  String? selectedDates;

final TextEditingController _chequeNumberController = TextEditingController();
final TextEditingController _chequeDateController = TextEditingController();

final TextEditingController _notesController = TextEditingController();


  static const List<String> choicesList = ['FACTURE', 'BC', 'BL'];

  DateTime? _date;
  String _choice = choicesList.first;

  final List<XFile> _picked = [];
  bool _saving = false;


@override
void initState() {
  super.initState();

  // Auto-format the date as DD-MM-YYYY
  _dateCtrl.addListener(() {
    String text = _dateCtrl.text;
    String digits = text.replaceAll(RegExp(r'[^0-9]'), ''); // keep only digits
    String formatted = '';

    for (int i = 0; i < digits.length && i < 8; i++) {
      formatted += digits[i];
      if ((i == 1 || i == 3) && i != digits.length - 1) formatted += '-';
    }

    if (formatted != text) {
      _dateCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  });
}



  @override
  void dispose() {
    _refCtrl.dispose();
    _dateCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }



  // ----------------- Compress Image -----------------
Future<File> _compressFile(File file) async {
  final path = '${file.parent.path}/compressed_${p.basename(file.path)}';

  try {
    // Compress the file
    final result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      path,
      format: CompressFormat.jpeg,
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


  // ----------------- Add Image Field -----------------

Future<void> _addImageField() async {
  final source = await showDialog<ImageSource>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Pick Image Source'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ImageSource.camera),
          child: const Text('Camera'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, ImageSource.gallery),
          child: const Text('Gallery'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );

  print('Debug: Selected source = $source'); // <--- Print selected source

  if (source == null) {
    print('Debug: User cancelled the source selection dialog.');
    return;
  }

  XFile? pickedFile;

  try {
    if (source == ImageSource.camera) {
      final cameras = await availableCameras();
      print('Debug: Available cameras = $cameras'); // <--- Print available cameras
      if (cameras.isNotEmpty) {
        final captured = await Navigator.of(context).push<XFile?>(
          MaterialPageRoute(
            builder: (_) => CameraCapturePage(camera: cameras.first),
          ),
        );
        print('Debug: Captured image = $captured'); // <--- Print captured file
        if (captured == null) {
          print('Debug: User did not capture any image.');
          return;
        }
        pickedFile = captured;
      } else {
        print('Debug: No cameras available');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No cameras available')));
        }
        return;
      }
    } else {
      pickedFile = await _picker.pickImage(source: source, imageQuality: 85);
      print('Debug: Picked image from gallery = $pickedFile'); // <--- Print gallery file
    }
  } catch (e) {
    print('Debug: Error picking image: $e'); // <--- Print any error
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
    return;
  }

  if (pickedFile != null && mounted) {
  final file = pickedFile; // Dart now treats 'file' as non-nullable
  setState(() => _picked.add(file));
}
 else {
    print('Debug: pickedFile is null'); // <--- Confirm null case
  }
}





Future<List<XFile>?> scanDocuments(BuildContext context, {int maxPages = 30}) async {
  try {
    final result = await FlutterDocScanner().getScanDocuments(page: maxPages);
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
      // Optional: if result is a List of paths, handle them too
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




Future<List<XFile>?> _pickFromGallery() async {
    try {
      final result = await ImagePicker().pickMultiImage(); // or pickImage for single
      if (result.isNotEmpty) {
        return result.map((e) => XFile(e.path)).toList();
      }
      return null;
    } catch (e) {
      debugPrint('Gallery pick failed: $e');
      return null;
    }
  }



Future<List<XFile>?> _pickFiles() async {
  try {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );

    if (result != null && result.files.isNotEmpty) {
      return result.files.map((file) => XFile(file.path!)).toList();
    }
    return null;
  } catch (e) {
    debugPrint('File pick failed: $e');
    return null;
  }
}



Future<void> _submit() async {
  void showAlert(String message) {
    print("⚠️ Alert: $message");
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Attention'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ---------------- Basic validation ----------------
  if (_refCtrl.text.trim().isEmpty) {
    showAlert('Veuillez entrer une référence');
    return;
  }
  if (_choice.isEmpty) {
    showAlert('Veuillez sélectionner un type');
    return;
  }
  if (_dateCtrl.text.trim().isEmpty) {
    showAlert('Veuillez choisir une date');
    return;
  }

  DateTime? parsedDate;
  try {
    final parts = _dateCtrl.text.split('-'); // DD-MM-YYYY
    parsedDate = DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );
  } catch (e) {
    showAlert('Format de date incorrect');
    return;
  }

  final bons = _bonControllers
      .map((c) => c.text.trim())
      .where((v) => v.isNotEmpty)
      .toList();

  // ---------------- Check if bons exist in database ----------------
  if (_choice == 'FACTURE' && bons.isNotEmpty) {
    for (String bon in bons) {
      print('🔹 Checking bon: $bon'); // Print the bon being checked
    

    
    final bonQuery = await FirebaseFirestore.instance
    .collection('archives')
    .where('reference', isEqualTo: bon)  // <-- match if the array contains this bon
    .where('choice', whereIn: ['BC', 'BL'] )
    .get();

    print('Documents found for "$bon": ${bonQuery.docs.length}'); // Print number of matching docs
    
    for (var doc in bonQuery.docs) {
      print('  Document ID: ${doc.id}');
      print('  Reference: ${doc['reference']}');
      print('  Choice: ${doc['choice']}');
      //print('  Bons: ${doc['bons']}');
      print('--------------------------');
    }

      if (bonQuery.docs.isEmpty) {
        showAlert('Le bon "$bon" n\'existe pas pour le type "$_choice". Veuillez l\'ajouter d\'abord.');
        return;
      }
    }
  }

  if (_choice == 'FACTURE') {
    if (bons.isEmpty) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Confirmation'),
              content: const Text('Do you want to complete without Bon?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false), // Cancel
                  child: const Text('No'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true), // Proceed
                  child: const Text('Yes'),
                ),
              ],
            ),
          );

          if (proceed != true) return; // Stop if user presses No
        }

    if (!_paid && !_not_paid) {
      showAlert('Veuillez sélectionner payé ou impayé');
      return;
    }
  }

  if (!_hibta && !_itri) {
    showAlert('Veuillez sélectionner HIBTA ou ITRI');
    return;
  }

  setState(() => _saving = true);

  try {
    final col = FirebaseFirestore.instance.collection('archives');

    final refId = _refCtrl.text.trim();
    final safeDocId = refId.replaceAll("/", "_");

    final duplicateQuery = await col
        .where('reference', isEqualTo: refId)
        .where('category', isEqualTo: widget.categoryTitle)
        .where('choice', isEqualTo: _choice)
        .get();

    if (duplicateQuery.docs.isNotEmpty) {
      showAlert('Une entrée avec cette référence et ce type existe déjà.');
      return;
    }

    // ---------------- Collect selected options ----------------
    String? selectedOptionCompany;
    if (_hibta) selectedOptionCompany = 'HIBTA';
    if (_itri) selectedOptionCompany = 'ITRI';

    String? selectedOptionPay; // Payé / Impayé
    if (_paid) selectedOptionPay = 'Payé';
    if (_not_paid) selectedOptionPay = 'Impayé';

    dynamic selectedOptionPayMethod; // Cheque/Virement/Espece/Effet dates
    dynamic selectedDates;

    if (_cheque) {
          selectedOptionPayMethod = 'CHEQUE';

          if (_chequeNumberController.text.isEmpty) {
            showAlert('Veuillez saisir le numéro de chèque!');
            return;
          }

          if (_chequeDateController.text.isEmpty) {
            showAlert('Veuillez saisir la date du chèque!');
            return;
          }

          selectedDates = _chequeDateController.text.trim();
        }

     else if (_espece) {
      selectedOptionPayMethod = 'ESPÉCE';
    } else if (_virement) {
      selectedOptionPayMethod = 'VIREMENT';
    } else if (_effet) {
      selectedOptionPayMethod = 'EFFET';
      final dates = _effetDateControllers
          .map((c) => c.text.trim())
          .where((d) => d.isNotEmpty)
          .toList();
      selectedDates = dates.isNotEmpty ? dates : null;
    } else {
      selectedOptionPayMethod = null;
      _cheque = false;
      _virement = false;
      _espece = false;
      _effet = false;
      _effetDateControllers.clear();
    }

    final docRef = col.doc(safeDocId);

    // ---------------- Upload cheque image ----------------
    String? chequeImageUrl;
    if (_cheque && _chequeImage != null) {
      final file = await _compressFile(File(_chequeImage!.path));
      final storageRef = FirebaseStorage.instance
          .ref('archives/$refId/cheque_${file.path.split('/').last}');
      await storageRef.putFile(file);
      chequeImageUrl = await storageRef.getDownloadURL();
    }

    // ---------------- Collect EFFET rows ----------------
    List<Map<String, dynamic>> effetRows = [];
    if (_effet) {
      for (int i = 0; i < _effetDateControllers.length; i++) {
        final dateText = _effetDateControllers[i].text.trim();
        final referenceText = _effetRefControllers[i].text.trim();
        final montantText = _effetMontantControllers[i].text.trim();

        if (dateText.isNotEmpty || referenceText.isNotEmpty || montantText.isNotEmpty) {
          DateTime? parsedEffetDate;
          if (dateText.isNotEmpty) {
            try {
              final parts = dateText.split('-');
              parsedEffetDate = DateTime(
                int.parse(parts[2]),
                int.parse(parts[1]),
                int.parse(parts[0]),
              );
            } catch (_) {
              showAlert('Format de date incorrect dans EFFET, ligne ${i + 1}');
              return;
            }
          }

          effetRows.add({
            'date': parsedEffetDate != null ? Timestamp.fromDate(parsedEffetDate) : null,
            'reference': referenceText.isNotEmpty ? referenceText : null,
            'montant': montantText.isNotEmpty ? double.tryParse(montantText) ?? 0.0 : null,
          });
        }
      }
    }

    // ---------------- Store document ----------------
    await docRef.set({
      'category': widget.categoryTitle,
      'reference': refId.toLowerCase(),
      'date': Timestamp.fromDate(parsedDate),
      'choice': _choice,
      'company': selectedOptionCompany,
      'amount': double.tryParse(_amountCtrl.text.trim()) ?? 0.0,
      'payment': selectedOptionPay,
      'paymentMethod': selectedOptionPayMethod,
      'num_cheque': _chequeNumberController.text.trim(),
      'dates': selectedDates,
      'client': (_choice == 'BC' && _clientCtrl.text.trim().isNotEmpty)
          ? _clientCtrl.text.trim()
          : '-',
      'bons': bons,
      'effetRows': effetRows, // ✅ store EFFET rows with date, reference, montant
      'images': [],
      'cheque_image': chequeImageUrl,
      'notes': _notesController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // ---------------- Upload other images ----------------
    // ---------------- Upload other images ----------------
  final imageList = await Future.wait(_picked.map((xfile) async {
    final file = await _compressFile(File(xfile.path));
    final storageRef =
        FirebaseStorage.instance.ref('archives/$refId/${file.path.split('/').last}');
    await storageRef.putFile(file);
    final url = await storageRef.getDownloadURL();
    return {'url': url, 'name': file.path.split('/').last};
  }));

  await docRef.update({'images': imageList});


    if (mounted) {
      showAlert('Enregistré avec succès');
      _refCtrl.clear();
      _amountCtrl.clear();
      _dateCtrl.clear();
      setState(() {
        _choice = 'FACTURE';
        _date = null;
        _hibta = false;
        _itri = false;
        _paid = false;
        _not_paid = false;
        _cheque = false;
        _virement = false;
        _espece = false;
        _effet = false;
        _effetDateControllers = [TextEditingController()];
        _effetRefControllers = [TextEditingController()];
        _effetMontantControllers = [TextEditingController()];
        _picked.clear();
        _bonControllers = [TextEditingController()];
        _notesController.clear();
        _chequeImage = null;
      });
    }
  } catch (e) {
    if (mounted) showAlert('Échec de l\'enregistrement : $e');
  } finally {
    if (mounted) setState(() => _saving = false);
  }
}




// Keep a list of controllers for dynamic Bon fields
List<TextEditingController> _bonControllers = [TextEditingController()];
List<TextEditingController> _effetDateControllers = [TextEditingController()];
List<TextEditingController> _effetRefControllers = [TextEditingController()];
List<TextEditingController> _effetMontantControllers = [TextEditingController()];


XFile? _chequeImage; // Add this at the top of your state

// Widget for Bon fields
Widget _buildBonFields() {
  return Column(
    children: List.generate(_bonControllers.length, (index) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(2, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              // Input Field
              Expanded(
                child: TextFormField(
                  controller: _bonControllers[index],
                  decoration: const InputDecoration(
                    labelText: 'Bon',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Bon requis' : null,
                ),
              ),

              // + Button
              IconButton(
                icon: const Icon(Icons.add, size: 20, color: Colors.green),
                onPressed: () {
                  setState(() {
                    _bonControllers.add(TextEditingController());
                  });
                },
              ),

              // - Button
              IconButton(
                icon: const Icon(Icons.remove, size: 20, color: Colors.red),
                onPressed: () {
                  if (_bonControllers.length > 1) {
                    setState(() {
                      _bonControllers.removeAt(index);
                    });
                  }
                },
              ),
            ],
          ),
        ),
      );
    }),
  );
}




Widget _buildChecksFields() {
  return Column(
    children: [
      // --- Payé / Impayé selection ---
      Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            CheckboxListTile(
              title: const Text(
                'Mode de réglement',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              value: _paid,
              onChanged: (val) {
                setState(() {
                  _paid = val ?? false;
                  if (_paid) {
                    _not_paid = false;
                  } else {
                    // Clear extra fields if not paid
                    _cheque = false;
                    _virement = false;
                    _espece = false;
                    _effet = false;
                    _chequeNumberController.clear();
                    _chequeDateController.clear();
                    _effetDateControllers.clear();
                  }
                });
              },
            ),
            CheckboxListTile(
              title: const Text(
                'Impayé',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              value: _not_paid,
              onChanged: (val) {
                setState(() {
                  _not_paid = val ?? false;
                  if (_not_paid) {
                    _paid = false;
                    _cheque = false;
                    _virement = false;
                    _espece = false;
                    _effet = false;
                    _chequeNumberController.clear();
                    _chequeDateController.clear();
                    _effetDateControllers.clear();
                  }
                });
              },
            ),
          ],
        ),
      ),

      const SizedBox(height: 16),

      // --- Payment methods (only if Payé is selected) ---
      if (_paid)
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(2, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              // Row 1: Cheque & Virement
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Cheque'),
                      value: _cheque,
                      onChanged: (val) {
                        setState(() {
                          _cheque = val ?? false;
                          if (_cheque) {
                            _virement = false;
                            _espece = false;
                            _effet = false;
                            _effetDateControllers.clear();
                          } else {
                            _chequeNumberController.clear();
                            _chequeDateController.clear();
                          }
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Virement'),
                      value: _virement,
                      onChanged: (val) {
                        setState(() {
                          _virement = val ?? false;
                          if (_virement) {
                            _cheque = false;
                            _espece = false;
                            _effet = false;
                            _chequeNumberController.clear();
                            _chequeDateController.clear();
                            _effetDateControllers.clear();
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),

              // ✅ Show Cheque Number input if Cheque is selected
if (_cheque)
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cheque Number
        TextField(
          controller: _chequeNumberController,
          decoration: const InputDecoration(
            labelText: 'Cheque Number',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),

        const SizedBox(height: 8),

        // Date de cheque
        TextField(
  controller: _chequeDateController,
  decoration: const InputDecoration(
    labelText: 'Date de chèque (dd-mm-yyyy)',
    border: OutlineInputBorder(),
  ),
  keyboardType: TextInputType.number,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(8), // ddMMyyyy = 8 digits
    TextInputFormatter.withFunction((oldValue, newValue) {
      var text = newValue.text;

      if (text.length >= 3 && text[2] != '-') {
        text = text.substring(0, 2) + '-' + text.substring(2);
      }
      if (text.length >= 6 && text[5] != '-') {
        text = text.substring(0, 5) + '-' + text.substring(5);
      }

      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }),
  ],
),



        const SizedBox(height: 12),

        // Upload buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final picker = ImagePicker();
                  final pickedFile =
                      await picker.pickImage(source: ImageSource.camera);
                  if (pickedFile != null) setState(() => _chequeImage = pickedFile);
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final picker = ImagePicker();
                  final pickedFile =
                      await picker.pickImage(source: ImageSource.gallery);
                  if (pickedFile != null) setState(() => _chequeImage = pickedFile);
                },
                icon: const Icon(Icons.photo_library),
                label: const Text('Select from Gallery'),
              ),
            ),
          ],
        ),

        // Image preview with delete button
        if (_chequeImage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Image.file(
                        File(_chequeImage!.path),
                        width: 150,
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _chequeImage = null; // Delete the image
                          });
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final XFile? picked =
                          await _picker.pickImage(source: ImageSource.gallery);
                      if (picked != null) {
                        setState(() {
                          _chequeImage = picked;
                        });
                      }
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Replace Image'),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  ),

              const SizedBox(height: 8),

              // Row 2: Espece & Effet
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Espèce'),
                      value: _espece,
                      onChanged: (val) {
                        setState(() {
                          _espece = val ?? false;
                          if (_espece) {
                            _cheque = false;
                            _virement = false;
                            _effet = false;
                            _chequeNumberController.clear();
                            _chequeDateController.clear();
                            _effetDateControllers.clear();
                          }
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Effet'),
                      value: _effet,
                      onChanged: (val) {
                        setState(() {
                          _effet = val ?? false;
                          if (_effet) {
                            _cheque = false;
                            _virement = false;
                            _espece = false;
                            _chequeNumberController.clear();
                            _chequeDateController.clear();
                            if (_effetDateControllers.isEmpty) {
                              _effetDateControllers.add(TextEditingController());
                            }
                          } else {
                            _effetDateControllers.clear();
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),

              // Dynamic Effet date fields
             if (_effet)
  Column(
    children: [
      for (int i = 0; i < _effetDateControllers.length; i++)
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Date field
                TextFormField(
                  controller: _effetDateControllers[i],
                  decoration: InputDecoration(
                    labelText: 'Date',
                    hintText: 'dd-mm-yyyy',
                    prefixIcon: const Icon(Icons.calendar_today, color: Colors.blue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8), // ddMMyyyy = 8 digits
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      var text = newValue.text;

                      if (text.length >= 3 && text[2] != '-') {
                        text = text.substring(0, 2) + '-' + text.substring(2);
                      }
                      if (text.length >= 6 && text[5] != '-') {
                        text = text.substring(0, 5) + '-' + text.substring(5);
                      }

                      return TextEditingValue(
                        text: text,
                        selection: TextSelection.collapsed(offset: text.length),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 12),

                // Reference field
                TextFormField(
                  controller: _effetRefControllers[i],
                  decoration: InputDecoration(
                    labelText: 'Référence',
                    prefixIcon: const Icon(Icons.tag, color: Colors.orange),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Montant field
                TextFormField(
                  controller: _effetMontantControllers[i],
                  decoration: InputDecoration(
                    labelText: 'Montant',
                    prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),

                // Add / Remove buttons aligned to the end
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.blue),
                      onPressed: () {
                        setState(() {
                          _effetDateControllers.add(TextEditingController());
                          _effetRefControllers.add(TextEditingController());
                          _effetMontantControllers.add(TextEditingController());
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          if (_effetDateControllers.isNotEmpty) {
                            _effetDateControllers.removeLast();
                            _effetRefControllers.removeLast();
                            _effetMontantControllers.removeLast();
                            if (_effetDateControllers.isEmpty) _effet = false;
                          }
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ],
  ),



            ],
          ),
        ),
    ],
  );
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
      title: Text('Ajouter — ${widget.categoryTitle}'),
      backgroundColor: color1,
      elevation: 4,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 15,
      ),
      iconTheme: const IconThemeData(
    color: Colors.white, // ← makes back arrow white
  ),
    ),
    resizeToAvoidBottomInset: true,
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Reference Field
// Reference Field
Container(
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.9),
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black12,
        blurRadius: 4,
        offset: Offset(2, 2),
      ),
    ],
  ),
  child: TextFormField(
    controller: _refCtrl,
    decoration: const InputDecoration(
      labelText: 'Reference',
      border: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    ),
    validator: (v) => (v == null || v.trim().isEmpty)
        ? 'Reference is required'
        : null,
  ),
),
const SizedBox(height: 6), // reduced from 10

// Type & Date Row
Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    // Row: Type + Date
    Row(
      children: [
        // Type Dropdown
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            child: DropdownButtonFormField<String>(
                value: _choice,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                ),
                items: choicesList
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _choice = v ?? choicesList.first;

                    // Clear checkboxes and selected option if choice is not FACTURE
                    if (_choice != 'FACTURE') {
                      _paid = false;
                      _not_paid = false;
                      selectedOptionPay = null;
                      _bonControllers = [TextEditingController()];
                      _cheque = false;
                      _virement = false;
                      _effet = false;
                      _effetDateControllers.clear();
                      _chequeNumberController.clear();
                      _chequeDateController.clear();
                      _chequeImage = null;
                    }

                    if (_choice != 'BC') {
                      _clientCtrl.clear();
                    }

                    

                  });
                },
              ),
          ),
        ),
        const SizedBox(width: 6),

        // Date Field
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            child: TextFormField(
              controller: _dateCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Date (DD-MM-YYYY)',
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                counterText: '',
              ),
              maxLength: 10,
              validator: (value) {
                if (value == null || value.trim().isEmpty)
                  return 'Veuillez entrer une date';
                if (!RegExp(r'\d{2}-\d{2}-\d{4}').hasMatch(value))
                  return 'Format incorrect';
                return null;
              },
            ),
          ),
        ),
      ],
    ),

    const SizedBox(height: 6),

    // Bon Field (if type is FACTURE)
   if (_choice == 'FACTURE') _buildBonFields(),


  ],
),


const SizedBox(height: 6), // reduced from 10

// Montant Field Container
Container(
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.9),
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black12,
        blurRadius: 4,
        offset: Offset(2, 2),
      ),
    ],
  ),
  padding: const EdgeInsets.all(8),
  child: TextFormField(
    controller: _amountCtrl,
    keyboardType: TextInputType.numberWithOptions(decimal: true),
    decoration: const InputDecoration(
      labelText: 'Montant',
      border: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    ),
    validator: (v) => (v == null || v.trim().isEmpty) ? 'Montant requis' : null,
  ),
),
const SizedBox(height: 6), // reduced from 12

// Client Field Container (only if type is BC)
if (_choice == 'BC')
  Container(
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.9),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black12,
          blurRadius: 4,
          offset: Offset(2, 2),
        ),
      ],
    ),
    padding: const EdgeInsets.all(8),
    child: TextFormField(
      controller: _clientCtrl,
      decoration: const InputDecoration(
        labelText: 'Client',
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Client requis' : null,
    ),
  ),
const SizedBox(height: 6), // reduced from 12




const SizedBox(height: 16),

Container(
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.9),
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black12,
        blurRadius: 4,
        offset: Offset(2, 2),
      ),
    ],
  ),
  child: Column(
    children: [
      CheckboxListTile(
        title: const Text('HIBTA', style: TextStyle(fontWeight: FontWeight.bold)),
        value: _hibta,
        onChanged: (val) {
          setState(() {
            _hibta = val ?? false;
            if (_hibta) _itri = false;
          });
        },
      ),
      CheckboxListTile(
        title: const Text('ITRI', style: TextStyle(fontWeight: FontWeight.bold)),
        value: _itri,
        onChanged: (val) {
          setState(() {
            _itri = val ?? false;
            if (_itri) _hibta = false;
          });
        },
      ),
    ],
  ),
),

const SizedBox(height: 16),

   if (_choice == 'FACTURE') _buildChecksFields(),




const SizedBox(height: 16),

          // Images Section
Container(
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.95), // clean white background
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black12,
        blurRadius: 6,
        offset: Offset(2, 2),
      ),
    ],
  ),
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,


children: [
  const Text(
    'Images/Fichiers',
    style: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
    ),
  ),
  const SizedBox(height: 12),

  SizedBox(
    height: 320,
    child: _picked.isEmpty
        ? Center(
            child: Icon(
              Icons.picture_as_pdf,
              size: 50,
              color: color3,
            ),
          )
        : ListView.builder(
            scrollDirection: Axis.vertical,
            itemCount: _picked.length,
            itemBuilder: (context, index) {
              final xfile = _picked[index];
              final fileExists = File(xfile.path).existsSync();

              if (!fileExists) {
                return Container(
                  height: 200,
                  color: Colors.redAccent.withOpacity(0.2),
                  child: Center(
                    child: Text('PDF not found!'),
                  ),
                );
              }

              return Stack(
  children: [
    Container(
      height: 460,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color2.withOpacity(0.5)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(2, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Builder(
          builder: (_) {
            final ext = p.extension(xfile.path).toLowerCase();
            if (ext == '.pdf') {
              // PDF viewer
              return SfPdfViewer.file(
                File(xfile.path),
                onDocumentLoaded: (details) {
                  print('DEBUG: PDF loaded successfully');
                },
                onDocumentLoadFailed: (error) {
                  print('DEBUG: PDF load failed: $error');
                },
              );
            } else if (['.jpg', '.jpeg', '.png'].contains(ext)) {
              // Image viewer
              return Image.file(
                File(xfile.path),
                fit: BoxFit.cover,
              );
            } else {
              // Fallback for unsupported file
              return Center(
                child: Text('Unsupported file type: $ext'),
              );
            }
          },
        ),
      ),
    ),
    Positioned(
      top: 12,
      right: 0,
      child: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.redAccent,
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close, size: 18, color: Colors.white),
          onPressed: () {
            setState(() {
              _picked.removeAt(index);
            });
          },
        ),
      ),
    ),
  ],
);

            },
          ),
  ),

  const SizedBox(height: 12),

  SizedBox(
    width: 60,
    height: 44,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: color3.withOpacity(0.2),
        side: BorderSide(color: color3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {
        showModalBottomSheet(
  context: context,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (context) => Wrap(
    children: [
      ListTile(
        leading: const Icon(Icons.photo),
        title: const Text('Pick from Gallery'),
        onTap: () async {
          Navigator.pop(context);
          final pickedFiles = await _pickFromGallery();
          if (pickedFiles != null) {
            setState(() {
              _picked.addAll(pickedFiles);
            });
          }
        },
      ),
      ListTile(
        leading: const Icon(Icons.insert_drive_file),
        title: const Text('Pick Files (PDF, DOC, etc.)'),
        onTap: () async {
          Navigator.pop(context);
          final pickedFiles = await _pickFiles();
          if (pickedFiles != null) {
            setState(() {
              _picked.addAll(pickedFiles);
            });
          }
        },
      ),
      ListTile(
        leading: const Icon(Icons.document_scanner),
        title: const Text('Scan Document'),
        onTap: () async {
          Navigator.pop(context);
          final scannedFiles = await scanDocuments(context, maxPages: 30);
          if (scannedFiles != null) {
            setState(() {
              _picked.addAll(scannedFiles);
            });
          }
        },
      ),
    ],
  ),
);

      },
      child: const Text(
        '+',
        style: TextStyle(fontSize: 20, color: Colors.black87),
      ),
    ),
  ),
],

  
  ),
),
const SizedBox(height: 24),

            

TextField(
  controller: _notesController,
  maxLines: 3,
  style: const TextStyle(
    color: Colors.black87,
    fontSize: 16,
  ),
  decoration: InputDecoration(
    labelText: 'Notes / Commentaires',
    labelStyle: const TextStyle(
      color: Color(0xFF7C4585), // color1
      fontWeight: FontWeight.w600,
    ),
    filled: true,
    fillColor: Colors.grey[200], // color4 as background
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(
        color: Color(0xFF9B7EBD), // color2 border
        width: 1.5,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(
        color: Color(0xFF7C4585), // color1 border when focused
        width: 2,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(
        color: Color(0xFFF49BAB), // color3 for error
        width: 1.5,
      ),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(
        color: Color(0xFFF49BAB),
        width: 2,
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(
      vertical: 16,
      horizontal: 20,
    ),
    hintText: "Écrire vos notes ici...",
    hintStyle: const TextStyle(
      color: Colors.black38,
      fontStyle: FontStyle.italic,
    ),
  ),
),



            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save, color: Colors.white),
                label: const Text('Enregistrer',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}



}

