import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Services/session_controller.dart';

// ── Action Constants ──────────────────────────────────────────────────────────
class LogAction {
  static const String create = 'CREATE';
  static const String update = 'UPDATE';
  static const String delete = 'DELETE';
  static const String view = 'VIEW';
  static const String login = 'LOGIN';
  static const String logout = 'LOGOUT';
  static const String export = 'EXPORT';
  static const String payment = 'PAYMENT'; // ← এই line যোগ করো
}

// ── Module Constants ──────────────────────────────────────────────────────────
class LogModule {
  static const String staff = 'staff';
  static const String cash = 'cash';
  static const String inventory = 'inventory';
  static const String sales = 'sales';
  static const String auth = 'auth';
  static const String admin = 'admin';
}

// ── Activity Logger ───────────────────────────────────────────────────────────
class ActivityLogger extends GetxService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> log({
    required String module,
    required String action,
    required String description,
    String? targetId,
  }) async {
    try {
      final session = Get.find<SessionController>();

      await _db.collection('activity_logs').add({
        'userId': session.userId,
        'userName': session.userName,
        'userRole': session.userRole,
        'module': module,
        'action': action,
        'description': description,
        'targetId': targetId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Silent fail — logging কখনো main feature break করবে না
    }
  }

  // ── Shortcuts ─────────────────────────────────────────────────────────────
  Future<void> logLogin(String userName) => log(
    module: LogModule.auth,
    action: LogAction.login,
    description: '$userName logged in',
  );

  Future<void> logLogout(String userName) => log(
    module: LogModule.auth,
    action: LogAction.logout,
    description: '$userName logged out',
  );

  Future<void> logCreate(
    String module,
    String description, {
    String? targetId,
  }) => log(
    module: module,
    action: LogAction.create,
    description: description,
    targetId: targetId,
  );

  Future<void> logUpdate(
    String module,
    String description, {
    String? targetId,
  }) => log(
    module: module,
    action: LogAction.update,
    description: description,
    targetId: targetId,
  );

  Future<void> logDelete(
    String module,
    String description, {
    String? targetId,
  }) => log(
    module: module,
    action: LogAction.delete,
    description: description,
    targetId: targetId,
  );

  Future<void> logExport(String module, String description) =>
      log(module: module, action: LogAction.export, description: description);
}
