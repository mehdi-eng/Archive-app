import 'dart:io';

import 'package:archive_app_new/firebase_service.dart';
import 'package:archive_app_new/images_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;


class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.categoryTitle});
  final String categoryTitle;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _refCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  DateTime? _selectedDate;
  //int? _choice; // 1..9
  String? _choice; // nullable

  static const color1 = Color(0xFF7C4585);
  static const color2 = Color(0xFF9B7EBD);
  static const color3 = Color(0xFFF49BAB);
  static const color4 = Color(0xFFFFE1E0);

  static const List<String> choicesList = ['FACTURE', 'BC', 'BL'];

  final TextEditingController _amountSearchCtrl = TextEditingController();

final TextEditingController _fromDateCtrl = TextEditingController();
final TextEditingController _toDateCtrl = TextEditingController();


  List<QueryDocumentSnapshot<Map<String, dynamic>>> _results = [];

  List<Map<String, dynamic>> resultsWithImages = [];

  List<Map<String, dynamic>> _resultsWithImages = [];


  bool _loading = false;
  

  double get totalAmount {
    return _results.fold(0.0, (sum, doc) {
      final data = doc.data() as Map<String, dynamic>;
      return sum + (data['amount'] != null ? (data['amount'] as num).toDouble() : 0.0);
    });
  }


  @override
  void dispose() {
    _refCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }



Future<void> _search() async {
  String ref = _refCtrl.text.trim().toLowerCase();

  String amountText = _amountSearchCtrl.text.trim();
  String fromDateText = _fromDateCtrl.text.trim();
  String toDateText = _toDateCtrl.text.trim();

  setState(() => _loading = true);

  final firebaseService = FirebaseService();
  final col = firebaseService.firestore.collection('archives');

  try {
    print('--- Starting search ---');

    Query<Map<String, dynamic>> q =
        col.where('category', isEqualTo: widget.categoryTitle);

    if (ref.isNotEmpty) {
      final refWithSlash = ref;
      final refWithUnderscore = ref.replaceAll("/", "_");
      q = q.where('reference', whereIn: [refWithSlash, refWithUnderscore]);
    }

    if (_choice != null && _choice!.isNotEmpty) {
      q = q.where('choice', isEqualTo: _choice);
    }

    if (amountText.isNotEmpty) {
      final amountValue = double.tryParse(amountText) ?? 0.0;
      q = q.where('amount', isEqualTo: amountValue);
    }

    if (fromDateText.isNotEmpty && toDateText.isNotEmpty) {
      final from = DateFormat('yyyy-MM-dd').parse(fromDateText);
      final to = DateFormat('yyyy-MM-dd').parse(toDateText);

      final start = Timestamp.fromDate(DateTime(from.year, from.month, from.day));
      final end = Timestamp.fromDate(DateTime(to.year, to.month, to.day, 23, 59, 59));

      q = q
          .where('date', isGreaterThanOrEqualTo: start)
          .where('date', isLessThanOrEqualTo: end)
          .orderBy('date', descending: true);
    } else {
      q = q.orderBy('date', descending: true);
    }

    // Execute the query
    QuerySnapshot<Map<String, dynamic>> snap = await q.get();
    _resultsWithImages = [];

    for (var doc in snap.docs) {
      final data = doc.data();

      // Fix reference formatting
      data['reference'] = (data['reference'] as String?)?.replaceAll("_", "/") ?? '-';
      data['client'] ??= '-';

      // Skip images completely
      // Do not merge bons images or cheque images

      // Save document with ID, without images
      _resultsWithImages.add({...data, 'id': doc.id});
    }

    setState(() {
      _results = snap.docs;
      _resultsWithImages = _resultsWithImages;
    });

    print('--- _resultsWithImages ---');
    for (var doc in _resultsWithImages) {
      print('📌 Document ID: ${doc['id']}');
      print('Reference: ${doc['reference']}');
      print('Category: ${doc['category']}');
      print('Choice: ${doc['choice']}');
      print('-------------------------');
    }

    print('✅ Search completed: ${_resultsWithImages.length} results found');
  } catch (e) {
    print('❌ Search failed: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search error: $e')),
      );
    }
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}



void _showRowOptions(QueryDocumentSnapshot<Map<String, dynamic>> doc) {



  
  showModalBottomSheet(
    context: context,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: Colors.blue),
              title: Text('Modify'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to modify page or show modify dialog
                _modifyDocument(doc);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _deleteDocument(doc);
              },
            ),
          ],
        ),
      );
    },
  );
}





void _modifyDocument(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();

  final refCtrl = TextEditingController(text: data['reference'] ?? '');
  String? choice = data['choice'];

  DateTime? selectedDate = (data['date'] as Timestamp?)?.toDate();
  final dateCtrl = TextEditingController(
      text: selectedDate != null ? DateFormat('yyyy-MM-dd').format(selectedDate) : '');
  final amountCtrl = TextEditingController(
      text: data['amount'] != null ? data['amount'].toString() : '0');
  final clientCtrl = TextEditingController(
      text: data['client'] ?? '');

  bool hibta = data['company'] == 'HIBTA';
  bool itri = data['company'] == 'ITRI';

  // Payment state
  bool paid = data['payment'] == 'Payé';
  bool notPaid = data['payment'] == 'Impayé';
  bool cheque = data['paymentMethod'] == 'CHEQUE';
  bool virement = data['paymentMethod'] == 'VIREMENT';
  bool espece = data['paymentMethod'] == 'ESPÉCE';
  bool effet = data['paymentMethod'] == 'EFFET';

  List<TextEditingController> effetDateControllers = [];

  final chequeNumberCtrl = TextEditingController(text: data['num_cheque'] ?? '');
  final notesCtrl = TextEditingController(text: data['notes'] ?? '');

  XFile? _chequeImage; // Add at the top of the builder


  if (effet && data['dates'] != null) {
    final dates = (data['dates'] as List<dynamic>).cast<String>();
    effetDateControllers = dates.map((d) => TextEditingController(text: d)).toList();
  } else {
    effetDateControllers = [TextEditingController()];
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 16,
          left: 16,
          right: 16,
        ),
        child: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Modify Document',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7C4585)),
                  ),
                  const SizedBox(height: 16),

                  // Reference
                  TextField(
                    controller: refCtrl,
                    decoration: InputDecoration(
                      labelText: 'Reference',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFFFFE1E0),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Type dropdown
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Type',
                      filled: true,
                      fillColor: const Color(0xFFFFE1E0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    dropdownColor: const Color(0xFFFFE1E0),
                    iconEnabledColor: Colors.black87,
                    value: choice,
                    items: choicesList
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => choice = v),
                  ),
                  const SizedBox(height: 12),

                  // Client field only if type is BC
                  if (choice == 'BC')
                    TextField(
                      controller: clientCtrl,
                      decoration: InputDecoration(
                        labelText: 'Client',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFFFFE1E0),
                      ),
                    ),
                  if (choice == 'BC') const SizedBox(height: 12),

                  // Date picker
                  TextField(
                    controller: dateCtrl,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFFFFE1E0),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today, color: Color(0xFF7C4585)),
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? now,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(now.year + 5),
                          );
                          if (picked != null) {
                            selectedDate = picked;
                            dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // HIBTA / ITRI checkboxes
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: const Color(0xFFFFE1E0),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          title: const Text('HIBTA'),
                          value: hibta,
                          onChanged: (val) {
                            setState(() {
                              hibta = val ?? false;
                              if (hibta) itri = false;
                            });
                          },
                        ),
                        CheckboxListTile(
                          title: const Text('ITRI'),
                          value: itri,
                          onChanged: (val) {
                            setState(() {
                              itri = val ?? false;
                              if (itri) hibta = false;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Amount
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFFFFE1E0),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- Payment checkboxes only if FACTURE ---
                  if (choice == 'FACTURE')
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      color: const Color(0xFFFFE1E0),
                      child: Column(
                        children: [
                          CheckboxListTile(
                            title: const Text('Payé'),
                            value: paid,
                            onChanged: (val) {
                              setState(() {
                                paid = val ?? false;
                                if (paid) notPaid = false;
                                if (!paid) {
                                  cheque = false;
                                  virement = false;
                                  espece = false;
                                  effet = false;
                                  effetDateControllers.clear();
                                }
                              });
                            },
                          ),
                          CheckboxListTile(
                            title: const Text('Impayé'),
                            value: notPaid,
                            onChanged: (val) {
                              setState(() {
                                notPaid = val ?? false;
                                if (notPaid) paid = false;
                              });
                            },
                          ),
                          if (paid)
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: CheckboxListTile(
                                        title: const Text('Cheque'),
                                        value: cheque,
                                        onChanged: (val) {
                                          setState(() {
                                            cheque = val ?? false;
                                            if (cheque) {
                                              virement = false;
                                              espece = false;
                                              effet = false;
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    Expanded(
                                      child: CheckboxListTile(
                                        title: const Text('Virement'),
                                        value: virement,
                                        onChanged: (val) {
                                          setState(() {
                                            virement = val ?? false;
                                            if (virement) {
                                              cheque = false;
                                              espece = false;
                                              effet = false;
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: CheckboxListTile(
                                        title: const Text('Espèce'),
                                        value: espece,
                                        onChanged: (val) {
                                          setState(() {
                                            espece = val ?? false;
                                            if (espece) {
                                              cheque = false;
                                              virement = false;
                                              effet = false;
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    Expanded(
                                      child: CheckboxListTile(
                                        title: const Text('Effet'),
                                        value: effet,
                                        onChanged: (val) {
                                          setState(() {
                                            effet = val ?? false;
                                            if (effet) {
                                              cheque = false;
                                              virement = false;
                                              espece = false;
                                              if (effetDateControllers.isEmpty) {
                                                effetDateControllers.add(TextEditingController());
                                              }
                                            } else {
                                              effetDateControllers.clear();
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                // Effet date fields
                                if (effet)
                                  Column(
                                    children: [
                                      for (int i = 0; i < effetDateControllers.length; i++)
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: effetDateControllers[i],
                                                decoration: const InputDecoration(
                                                  labelText: 'Date (dd-mm-yyyy)',
                                                ),
                                                keyboardType: TextInputType.number,
                                              ),
                                            ),
                                            Column(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.add),
                                                  onPressed: () {
                                                    setState(() => effetDateControllers.add(TextEditingController()));
                                                  },
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.remove),
                                                  onPressed: () {
                                                    setState(() {
                                                      if (effetDateControllers.isNotEmpty) {
                                                        effetDateControllers.removeLast();
                                                      }
                                                    });
                                                  },
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),

                                  if (cheque)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: chequeNumberCtrl,
              decoration: InputDecoration(
                labelText: 'Numéro de chèque',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: const Color(0xFFFFE1E0),
              ),
            ),
            const SizedBox(height: 8),
            // Image picker button
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.image),
                  label: const Text('Choisir image'),
                  onPressed: () async {
                    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                    if (picked != null) {
                      setState(() {
                        _chequeImage = picked;
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                if (_chequeImage != null)
                  Image.file(
                    File(_chequeImage!.path),
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
              ],
            ),
          ],
        ),
      ),
  

                              ],
                            ),
                        ],
                      ),
                    ),


const SizedBox(height: 12),

TextField(
  controller: notesCtrl,
  maxLines: 3,
  decoration: InputDecoration(
    labelText: 'Notes / Commentaires',
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    filled: true,
    fillColor: const Color(0xFFE0E0E0), // gray background
  ),
),

                  const SizedBox(height: 12),

                  // Modify button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C4585),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        if (refCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Reference is required')),
                          );
                          return;
                        }

                        try {
                          // Prepare paymentMethod and dates for Firestore
                          String paymentMethod = '';
                          if (cheque) paymentMethod = 'CHEQUE';
                          if (virement) paymentMethod = 'VIREMENT';
                          if (espece) paymentMethod = 'ESPÈCE';
                          if (effet) paymentMethod = 'EFFET';
                          List<String> dates = effet
                              ? effetDateControllers.map((c) => c.text.trim()).where((d) => d.isNotEmpty).toList()
                              : [];

                          String? chequeImageUrl;

                          if (_chequeImage != null) {
                            final file = File(_chequeImage!.path);
                            final storageRef = FirebaseStorage.instance
                                .ref('archives/${refCtrl.text.trim()}/cheque/${p.basename(file.path)}');
                            await storageRef.putFile(file);
                            chequeImageUrl = await storageRef.getDownloadURL();
                          }

                          await doc.reference.update({
                            'reference': refCtrl.text.trim(),
                            'choice': choice,
                            'date': selectedDate != null ? Timestamp.fromDate(selectedDate!) : null,
                            'company': hibta ? 'HIBTA' : itri ? 'ITRI' : null,
                            'amount': double.tryParse(amountCtrl.text.trim()) ?? 0.0,
                            'client': choice == 'BC' && clientCtrl.text.trim().isEmpty ? '-' : clientCtrl.text.trim(),
                            'payment': paid ? 'Payé' : notPaid ? 'Impayé' : null,
                            'paymentMethod': paymentMethod,
                            'dates': dates,
                            'num_cheque': cheque ? chequeNumberCtrl.text.trim() : null,
                            'cheque_image': chequeImageUrl, // ← store image URL in Firestore
                            'notes': notesCtrl.text.trim(),
                          });


                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Document updated successfully')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Update failed: $e')),
                          );
                        }
                      },
                      child: const Text('Modify', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}




void _deleteDocument(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
  final data = doc.data();
  final reference = data['reference'];
  final choice = data['choice'];
  final company = data['company'];

// Debug prints
  print('Reference: $reference');
  print('Type/Choice: $choice');
  print('Company: $company');

  if (reference == null || choice == null || company == null) {
    print('Cannot delete: missing reference, type, or company');
    return;
  }

  // Show confirmation dialog
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm Deletion'),
      content:  RichText(
  text: TextSpan(
    style: const TextStyle(
      fontSize: 16,
      color: Colors.black87,
    ),
    children: [
      const TextSpan(text: 'Êtes-vous sûr de vouloir supprimer le document "'),
      TextSpan(
        text: reference,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      const TextSpan(text: '" de type "'),
      TextSpan(
        text: choice,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      const TextSpan(text: '" de la société "'),
      TextSpan(
        text: company,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      const TextSpan(text: '" ?'),
    ],
  ),
),

      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Yes'),
        ),
      ],
    ),
  );

  if (confirm != true) return; // User cancelled

  try {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('archives')
        .where('reference', isEqualTo: reference)
        .where('choice', isEqualTo: choice)
        .where('company', isEqualTo: company)
        .get();

    for (var docToDelete in querySnapshot.docs) {
      await docToDelete.reference.delete();
      print('Deleted document: ${docToDelete.id}');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${querySnapshot.docs.length} document(s)')),
    );
  } catch (e) {
    print('Deletion failed: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deletion failed: $e')),
    );
  }
}




Future<void> _pickFromDate() async {
  final picked = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  if (picked != null) {
    setState(() => _fromDateCtrl.text = DateFormat('yyyy-MM-dd').format(picked));
  }
}

Future<void> _pickToDate() async {
  final picked = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  if (picked != null) {
    setState(() => _toDateCtrl.text = DateFormat('yyyy-MM-dd').format(picked));
  }
}


@override
Widget build(BuildContext context) {


  return Scaffold(
    backgroundColor: color4,
    appBar: AppBar(
      title: Text('Recherche ${widget.categoryTitle}'),
      backgroundColor: color1,
      elevation: 6,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      centerTitle: true,
      titleTextStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
      iconTheme: const IconThemeData(
    color: Colors.white, // ← makes back arrow white
  ),
    ),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 🔹 Filters card with gradient
Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(20),
    gradient: LinearGradient(
      colors: [color3.withOpacity(0.2), color2],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    boxShadow: [
      BoxShadow(
        color: color3.withOpacity(0.3),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 🔹 Reference + Type Row
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Reference field
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.44, // 40% of screen width
              child: TextField(
                controller: _refCtrl,
                decoration: InputDecoration(
                  labelText: 'Reference',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Type dropdown
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Type',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                value: _choice,
                items: choicesList
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _choice = v),
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 12),

      // 🔹 Montant (full width)
      TextField(
        controller: _amountSearchCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Montant',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),



      const SizedBox(height: 12),

      // 🔹 From - To date pickers
      Row(
        children: [
          // From
          Expanded(
            child: TextField(
              controller: _fromDateCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'De',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  onPressed: _pickFromDate,
                  icon: const Icon(Icons.calendar_today),
                  color: color1,
                ),
              ),
              onTap: _pickFromDate,
            ),
          ),
          const SizedBox(width: 12),

          // To
          Expanded(
            child: TextField(
              controller: _toDateCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'à',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  onPressed: _pickToDate,
                  icon: const Icon(Icons.calendar_today),
                  color: color1,
                ),
              ),
              onTap: _pickToDate,
            ),
          ),
        ],
      ),
    ],
  ),
)
,
          const SizedBox(height: 16),

          // 🔹 Search button with gradient shadow
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: color1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
              ),
              onPressed: _loading ? null : _search,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.search, color: Colors.white),
              label: const Text('Chercher', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),

          // After the Chercher button
                const SizedBox(height: 16),

Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      'Nombre de documents : ${_results.length}',
      style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
    ),
    const SizedBox(height: 4),
    Row(
      children: [
        Text(
          'Total des montants : ${totalAmount.toStringAsFixed(2)} DH',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
  
      ],
    ),
  ],
),


          const SizedBox(height: 14),

          // 🔹 Results table with rounded container
          Expanded(
  child: _resultsWithImages.isEmpty
      ? SingleChildScrollView(
  child: Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.info_outline, size: 60, color: color2),
        const SizedBox(height: 12),
        const Text(
          "Aucun document",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          "Essayez d'ajuster vos filtres de recherche",
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
      ],
    ),
  ),
)

      : Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color2.withOpacity(0.3),
                blurRadius: 60,   // larger blur
                spreadRadius: 2,  // spread for stronger effect
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: color3.withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 1,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 400),

child: DataTable(
  showCheckboxColumn: false,
  headingRowColor: MaterialStateProperty.all(color3.withOpacity(0.3)),
  headingTextStyle: const TextStyle(
    fontWeight: FontWeight.bold,
    color: Colors.black87,
    fontSize: 16,
  ),
  dataRowHeight: 60,
  columns: const [
    DataColumn(label: Text('Date')),                 // Document date
    DataColumn(label: Text('Reference')),
    DataColumn(label: Text('Type')),
    DataColumn(label: Text('Montant')),             // Total amount
    DataColumn(label: Text('Paiement')),            // Payé / Impayé
    DataColumn(label: Text('Mode Paiement')),    // Cheque / Virement / Espèce / Effet
    DataColumn(label: Text('Montant Paiement')),    // ← New column for montant
    DataColumn(label: Text('N° Chèque / Effet')),   // ← Show cheque number or Effet references
    DataColumn(label: Text('Date')),               // Effet dates (multi-line)
    DataColumn(label: Text('Notes')),
    DataColumn(label: Text('Client')),
    DataColumn(label: Text('Bon')),
    DataColumn(label: Text('Entreprise')),
    DataColumn(label: Text('N. Documents')),
  ],


rows: _results.map((doc) {
  final data = _resultsWithImages.firstWhere(
    (d) => (d['id'] as String?)?.trim() == doc.id.trim(),
    orElse: () => {},
  );

  final images = List<Map<String, dynamic>>.from(data['images'] ?? []);

  // Determine row color
  /* rowColor = Colors.white; // default
  if (images.any((img) => (img['name'] as String?)?.toLowerCase().contains('bon') ?? false)) {
    rowColor = Colors.green.shade100;
  } else if (images.any((img) => (img['name'] as String?)?.toLowerCase().contains('cheque') ?? false)) {
    rowColor = Colors.yellow.shade100;
  }*/

  final reference = data['reference'] ?? '';
  final type = data['choice'] ?? '';
  final date = (data['date'] as Timestamp?)?.toDate();
  final formattedDate = date != null ? DateFormat('yyyy-MM-dd').format(date) : '';
  final company = data['company'] ?? '';
  final payment = data['payment'] ?? '';
  final amount = data['amount'] != null ? data['amount'].toString() : '0';
  final client = data['client'] ?? '-';
  final bons = (data['bons'] as List<dynamic>?)?.cast<String>() ?? [];
  final bonText = bons.isNotEmpty ? bons.join(' | ') : '-';
  final notes = (data['notes']?.toString().trim().isEmpty ?? true) ? '-' : data['notes']!.toString();
  final chequeNumber = data['num_cheque']?.toString() ?? '-';

  // Payment Method & Effet
  String payMethod = data['paymentMethod']?.toString() ?? '-';
  String effetDates = formattedDate;
  String effetRefs = '-';
  String effetMontants = '-';
  if (payMethod == 'EFFET' && data['effetRows'] != null) {
    final List<Map<String, dynamic>> effetRows = List<Map<String, dynamic>>.from(data['effetRows']);
    if (effetRows.isNotEmpty) {
      effetDates = effetRows.map((e) {
        final d = e['date'] as Timestamp?;
        return d != null ? DateFormat('yyyy-MM-dd').format(d.toDate()) : '-';
      }).join('\n');
      effetRefs = effetRows.map((e) => e['reference'] ?? '-').join('\n');
      effetMontants = effetRows.map((e) => e['montant']?.toString() ?? '0').join('\n');
    }
  }

  return DataRow(
    //color: MaterialStateProperty.all(rowColor),
    onLongPress: () => _showRowOptions(doc),
    cells: [
      DataCell(Text(formattedDate)),
      DataCell(Text(reference)),
      DataCell(Text(type)),
      DataCell(Text(amount)),
      DataCell(Text(payment)),
      DataCell(Text(payMethod)),
      DataCell(Text(effetMontants)),
      DataCell(Text(payMethod == 'EFFET' ? effetRefs : chequeNumber)),
      DataCell(Text(effetDates)),
      DataCell(Text(notes)),
      DataCell(Text(client)),
      DataCell(Text(bonText)),
      DataCell(Text(company)),
      DataCell(Text(images.length.toString())),
    ],
    onSelectChanged: (selected) {
      if (selected == true) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ImagesPage(
              images: images,
              docId: doc.id, 
              rowData: data, 
            ),
          ),
        );
      }
    },
  );
}).toList(),


),


              ),
            ),
          ),
        ),
),

        ],
      ),
    ),
  );
}


}


