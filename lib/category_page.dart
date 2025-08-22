
import 'dart:io';

import 'package:archive_app_new/menu_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:share_plus/share_plus.dart';



Future<void> uploadFournisseur(String name) async {
  final picker = ImagePicker();
  final pickedFile = await picker.pickImage(source: ImageSource.gallery);

  if (pickedFile != null) {
    File file = File(pickedFile.path);

    try {
      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child('logos/$name.png');
      await storageRef.putFile(file);
      final logoUrl = await storageRef.getDownloadURL();

      // Save to Firestore
      await FirebaseFirestore.instance.collection('fournisseurs').doc(name).set({
        'name': name,
        'logo_url': logoUrl,
      });

      print('Fournisseur uploaded successfully!');
    } catch (e) {
      print('Error: $e');
    }
  } else {
    print('No image selected.');
  }
}




class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    const color1 = Color(0xFF7C4585);
    const color2 = Color(0xFF9B7EBD);
    const color3 = Color(0xFFF49BAB);
    const color4 = Color(0xFFFFE1E0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Les Fournisseurs'),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        backgroundColor: color1,
        iconTheme: const IconThemeData(
    color: Colors.white, // ← makes back arrow white
  ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [color4, color3, color2, color1],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(12.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('fournisseurs').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "Erreur de connexion.\nVérifiez votre internet.",
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  "Aucun fournisseur trouvé",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final fournisseurs = snapshot.data!.docs;

            return GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: fournisseurs.length,
              itemBuilder: (context, index) {
                final doc = fournisseurs[index];
                final name = doc['name'] ?? 'No Name';
                final logoUrl = doc['logo_url'] ?? '';

               return ElevatedButton(
  onPressed: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MenuPage(categoryTitle: name, logoUrl: logoUrl),
      ),
    );
  },
  onLongPress: () async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le fournisseur'),
        content: Text('Voulez-vous vraiment supprimer "$name" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Delete Firestore document
        await FirebaseFirestore.instance.collection('fournisseurs').doc(name).delete();

        // Delete logo from Storage
        final storageRef = FirebaseStorage.instance.ref().child('logos/$name.png');
        await storageRef.delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fournisseur "$name" supprimé avec succès')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la suppression: $e')),
          );
        }
      }
    }
  },
  style: ElevatedButton.styleFrom(
    padding: const EdgeInsets.all(8),
    backgroundColor: Colors.white.withOpacity(0.8),
    shadowColor: Colors.black26,
    elevation: 6,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  ),
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      if (logoUrl.isNotEmpty)
        Image.network(
          logoUrl,
          height: 50,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.image_not_supported, size: 50, color: Colors.white);
          },
        ),
      const SizedBox(height: 8),
      Text(
        name,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: color1,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  ),
);

              },
            );
          },
        ),
      ),
floatingActionButton: FloatingActionButton(
  onPressed: () async {
    final TextEditingController nameController = TextEditingController();
    final picker = ImagePicker();
    XFile? pickedFile;

    // Show dialog to enter name (logo optional)
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un Fournisseur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nom du fournisseur',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.image),
              label: const Text('Sélectionner une image (optionnel)'),
              onPressed: () async {
                pickedFile = await picker.pickImage(source: ImageSource.gallery);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty) return;
              Navigator.of(context).pop();
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    if (nameController.text.isEmpty) return; // require name

    String logoUrl = '';
    try {
      if (pickedFile != null) {
        // Upload image if selected
        File file = File(pickedFile!.path);
        final storageRef =
            FirebaseStorage.instance.ref().child('logos/${nameController.text}.png');
        await storageRef.putFile(file);
        logoUrl = await storageRef.getDownloadURL();
      }

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('fournisseurs')
          .doc(nameController.text)
          .set({
        'name': nameController.text,
        'logo_url': logoUrl,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fournisseur ajouté avec succès')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  },
  backgroundColor: color3,
  child: const Icon(Icons.add, color: Colors.white),
),

    );
  }
}



