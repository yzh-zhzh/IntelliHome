import 'package:flutter/material.dart';
import 'package:intellihome_application/control_panel.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: ControlPanelPage(),
    );
  }
}
