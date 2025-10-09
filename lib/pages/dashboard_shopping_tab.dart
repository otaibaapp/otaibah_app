import 'package:flutter/material.dart';
import 'dashboard.dart';

class DashboardShoppingTab extends StatelessWidget {
  const DashboardShoppingTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Dashboard(initialIndex: 2); // 👈 تبويب التسوق
  }
}
