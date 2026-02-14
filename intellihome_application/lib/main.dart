// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:intellihome_application/control_panel.dart';
import 'package:intellihome_application/home_dashboard.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeDashboard(),
    );
  }
}
