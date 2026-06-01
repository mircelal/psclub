import 'package:flutter/material.dart';
import 'discounts_screen.dart';

/// Geriyə uyğunluq — Endirimlər hubuna yönləndirir.
class CustomerGroupsScreen extends StatelessWidget {
  const CustomerGroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DiscountsScreen(initialTab: DiscountAdminTab.customerGroups);
  }
}
