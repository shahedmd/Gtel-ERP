import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class PermissionController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final permissions = <String, Map<String, bool>>{}.obs;
  final isReady = false.obs;

  StreamSubscription<DocumentSnapshot>? _sub;

  @override
  void onInit() {
    super.onInit();
    _listen();
  }

  void _listen() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      isReady.value = true;
      return;
    }

    _sub = _db.collection('users').doc(uid).snapshots().listen((snap) {
      final data = snap.data() ?? {};
      final raw = data['permissions'] as Map<String, dynamic>? ?? {};

      final Map<String, Map<String, bool>> parsed = {};
      raw.forEach((module, actions) {
        if (actions is Map) {
          parsed[module] = actions.map(
            (k, v) => MapEntry(k.toString(), v == true),
          );
        }
      });

      permissions.value = parsed;
      isReady.value = true;
    });
  }

  bool can(String moduleKey, [String action = 'view']) {
    return permissions[moduleKey]?[action] == true;
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}