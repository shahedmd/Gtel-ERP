import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String role;
  final bool isActive;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
  });

  bool get isSuperAdmin => role == 'super_admin';

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      name: data['name'] ?? 'Unknown',
      email: data['email'] ?? '',
      role: data['role'] ?? 'viewer',
      isActive: data['isActive'] ?? true,
    );
  }
}

class SessionController extends GetxService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final Rx<AppUser?> currentUser = Rx<AppUser?>(null);
  final RxBool isSessionLoaded = false.obs;

  String get userId => currentUser.value?.uid ?? '';
  String get userName => currentUser.value?.name ?? 'Unknown';
  String get userRole => currentUser.value?.role ?? 'viewer';
  bool get isSuperAdmin => currentUser.value?.isSuperAdmin ?? false;

  // ── শুধু data load করে, auth listen করে না ──────────────────────────────
  Future<bool> loadSession(String uid) async {
    try {
      isSessionLoaded.value = false; // reset before loading
      final doc = await _db.collection('users').doc(uid).get();

      if (!doc.exists) {
        _setFallbackUser(uid);
        return true;
      }

      final user = AppUser.fromFirestore(doc);

      if (!user.isActive) return false;

      currentUser.value = user;
      isSessionLoaded.value = true;
      return true;
    } catch (e) {
      _setFallbackUser(uid);
      return true;
    }
  }

  void clearSession() {
    currentUser.value = null;
    isSessionLoaded.value = false;
  }

  void _setFallbackUser(String uid) {
    currentUser.value = AppUser(
      uid: uid,
      name: 'Admin',
      email: '',
      role: 'super_admin',
      isActive: true,
    );
    isSessionLoaded.value = true;
  }
}
