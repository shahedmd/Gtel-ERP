import 'package:get/get.dart';
import 'package:gtel_erp/Core/Services/session_controller.dart';

class RoleController extends GetxController {
  SessionController get _session => Get.find<SessionController>();

  bool get isSuperAdmin => _session.isSuperAdmin;
  String get currentUserEmail => _session.currentUser.value?.email ?? '';
  String get currentUserName => _session.userName;
  String get currentUserRole => _session.userRole;
}