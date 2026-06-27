import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class PermissionController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final permissions = <String, Map<String, bool>>{}.obs;
  final isReady = false.obs;

  StreamSubscription<DocumentSnapshot>? _firestoreSub;
  StreamSubscription<User?>? _authSub;

  @override
  void onInit() {
    super.onInit();
    _listenToAuth();
  }

  // ── Firebase Auth state listen করো ───────────────────────────────────────
  // App restart হলে Auth restore হওয়ার পরে Firestore listen শুরু হবে
  void _listenToAuth() {
    _authSub = _auth.authStateChanges().listen((user) {
      if (user != null) {
        // User logged in বা restored → Firestore listen শুরু করো
        _listenToFirestore(user.uid);
      } else {
        // User logged out → সব clear করো
        _firestoreSub?.cancel();
        _firestoreSub = null;
        permissions.value = {};
        isReady.value = false;
      }
    });
  }

  // ── Firestore থেকে real-time permissions listen করো ──────────────────────
  void _listenToFirestore(String uid) {
    // আগের subscription cancel করো
    _firestoreSub?.cancel();

    _firestoreSub = _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
          (snap) {
            if (!snap.exists) {
              // Document নেই — super_admin fallback
              permissions.value = {};
              isReady.value = true;
              return;
            }

            final data = snap.data() ?? {};

            // Account deactivated হলে logout করো
            final isActive = data['isActive'] ?? true;
            if (!isActive) {
              _auth.signOut();
              return;
            }

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
          },
          onError: (e) {
            // Error হলেও ready করো — super_admin fallback
            isReady.value = true;
          },
        );
  }

  // ── Permission check ──────────────────────────────────────────────────────
  bool can(String moduleKey, [String action = 'view']) {
    return permissions[moduleKey]?[action] == true;
  }

  @override
  void onClose() {
    _firestoreSub?.cancel();
    _authSub?.cancel();
    super.onClose();
  }
}
