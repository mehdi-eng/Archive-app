
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() => _instance;

  FirebaseService._internal();

  bool _initialized = false;
  late FirebaseFirestore firestore;
  //late FirebaseAuth auth;
  late FirebaseStorage storage;

  Future<void> initialize() async {
    if (!_initialized) {
      firestore = FirebaseFirestore.instance;
      //auth = FirebaseAuth.instance;
      storage = FirebaseStorage.instance;
      _initialized = true;
    }
  }
}

