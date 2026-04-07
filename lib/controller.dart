import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

enum UserRole { superAdmin, admin }

class RoleController extends GetxController {
  // 1. Define your Super Admin emails here (Hardcoded for now since you have no DB)
  final List<String> superAdminEmails = [
    'gtel01720677206@gmail.com', // Replace with actual super admin email
  ];

  var currentUserEmail = ''.obs;
  var userRole = UserRole.admin.obs; // Default to standard admin

  @override
  void onInit() {
    super.onInit();
    _checkUserRole();
  }

  void _checkUserRole() {
    // Get current user from Firebase Auth
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null && user.email != null) {
      currentUserEmail.value = user.email!;

      // Assign role based on email
      if (superAdminEmails.contains(user.email)) {
        userRole.value = UserRole.superAdmin;
      } else {
        userRole.value = UserRole.admin;
      }
    }
  }

  bool get isSuperAdmin => userRole.value == UserRole.superAdmin;
}
