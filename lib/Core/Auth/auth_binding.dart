import 'package:get/get.dart';
import 'package:gtel_erp/Core/Auth/auth.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AuthController(), permanent: true);
  }
}
