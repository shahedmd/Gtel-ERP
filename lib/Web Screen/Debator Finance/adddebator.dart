import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'debatorcontroller.dart';

void adddebatorDialog(DebatorController controller) {
  final nameC = TextEditingController();
  final shopC = TextEditingController();
  final nidC = TextEditingController();
  final phoneC = TextEditingController();
  final addressC = TextEditingController();

  final payments = <Map<String, dynamic>>[].obs;

  /// -------- ADD PAYMENT FORM (CASH DEFAULT) ----------
  void addPaymentForm() {
    payments.add({
      "type": "cash".obs, // ✅ CASH AS DEFAULT
      "bkash": TextEditingController(),
      "nagad": TextEditingController(),
      "bankName": TextEditingController(),
      "bankAcc": TextEditingController(),
      "bankBranch": TextEditingController(),
    });
  }

  /// add first payment by default
  addPaymentForm();

  Get.defaultDialog(
    title: "Add Debtor Account",
    radius: 10,
    barrierDismissible: false,
    content: Obx(
      () => SizedBox(
        width: Get.width * 0.85,
        height: Get.height * 0.65,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// -------- NAME + SHOP --------
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: nameC,
                      style: TextStyle(fontSize: 13),
                      decoration: InputDecoration(hintText: "Full Name"),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: shopC,
                      style: TextStyle(fontSize: 13),
                      decoration: InputDecoration(hintText: "Shop Name"),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),

              /// -------- NID + PHONE --------
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: nidC,
                      style: TextStyle(fontSize: 13),
                      decoration: InputDecoration(hintText: "NID Number"),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: phoneC,
                      style: TextStyle(fontSize: 13),
                      decoration: InputDecoration(hintText: "Phone Number"),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),

              /// -------- ADDRESS --------
              TextField(
                controller: addressC,
                style: TextStyle(fontSize: 13),
                decoration: InputDecoration(hintText: "Address"),
              ),
              SizedBox(height: 15),

              /// -------- PAYMENT HEADER --------
              Row(
                children: [
                  Text("Payment Methods",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.add_circle, color: Colors.green),
                    onPressed:
                        controller.isAddingBody.value ? null : addPaymentForm,
                  ),
                ],
              ),

              /// -------- PAYMENT CARDS --------
              Column(
                children: List.generate(payments.length, (index) {
                  var p = payments[index];

                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Obx(
                      () => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          /// PAYMENT TYPE DROPDOWN
                          DropdownButton<String>(
                            value: p["type"].value,
                            isExpanded: true,
                            items: ["cash", "bkash", "nagad", "bank"]
                                .map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e.toUpperCase()),
                                    ))
                                .toList(),
                            onChanged: controller.isAddingBody.value
                                ? null
                                : (v) => p["type"].value = v!,
                          ),
                          SizedBox(height: 10),

                          /// -------- CASH (DEFAULT) --------
                          if (p["type"].value == "cash")
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.green),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.money, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text(
                                    "Cash Payment (BDT)",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          /// -------- BKASH --------
                          if (p["type"].value == "bkash")
                            TextField(
                              controller: p["bkash"],
                              decoration:
                                  InputDecoration(hintText: "bKash Number"),
                            ),

                          /// -------- NAGAD --------
                          if (p["type"].value == "nagad")
                            TextField(
                              controller: p["nagad"],
                              decoration:
                                  InputDecoration(hintText: "Nagad Number"),
                            ),

                          /// -------- BANK --------
                          if (p["type"].value == "bank") ...[
                            TextField(
                              controller: p["bankName"],
                              decoration:
                                  InputDecoration(hintText: "Bank Name"),
                            ),
                            SizedBox(height: 6),
                            TextField(
                              controller: p["bankAcc"],
                              decoration:
                                  InputDecoration(hintText: "Account Number"),
                            ),
                            SizedBox(height: 6),
                            TextField(
                              controller: p["bankBranch"],
                              decoration:
                                  InputDecoration(hintText: "Branch Name"),
                            ),
                          ],

                          /// -------- DELETE BUTTON --------
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: controller.isAddingBody.value
                                  ? null
                                  : () => payments.removeAt(index),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),

              SizedBox(height: 20),

              /// -------- LOADING --------
              if (controller.isAddingBody.value)
                Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    ),

    textConfirm: "Save",
    textCancel: "Cancel",

    onConfirm: () async {
      if (controller.isAddingBody.value) return;

      if (nameC.text.isEmpty ||
          shopC.text.isEmpty ||
          nidC.text.isEmpty ||
          phoneC.text.isEmpty ||
          addressC.text.isEmpty) {
        Get.snackbar("Error", "Fill all debtor fields!",
            backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }

      if (payments.isEmpty) {
        Get.snackbar("Error", "Add at least one payment method!",
            backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }

      final List<Map<String, dynamic>> finalPayments = [];

      for (var p in payments) {
        if (p["type"].value == "cash") {
          finalPayments.add({
            "type": "cash",
            "currency": "BDT",
          });
        } else if (p["type"].value == "bkash") {
          finalPayments.add({
            "type": "bkash",
            "number": p["bkash"].text,
          });
        } else if (p["type"].value == "nagad") {
          finalPayments.add({
            "type": "nagad",
            "number": p["nagad"].text,
          });
        } else if (p["type"].value == "bank") {
          finalPayments.add({
            "type": "bank",
            "bankName": p["bankName"].text,
            "accountNumber": p["bankAcc"].text,
            "branch": p["bankBranch"].text,
          });
        }
      }

      controller.isAddingBody.value = true;

      await controller.addBody(
        name: nameC.text,
        des: shopC.text,
        nid: nidC.text,
        phone: phoneC.text,
        address: addressC.text,
        payments: finalPayments,
      );

      controller.isAddingBody.value = false;
      Get.back();
    },
  );
}
