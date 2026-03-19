import 'package:flutter/material.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: const Text(
        'Property of Shi Hi Family',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
    );
  }
}
