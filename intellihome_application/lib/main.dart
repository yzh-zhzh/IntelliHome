// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:intellihome_application/control_panel.dart';
import 'package:intellihome_application/home_dashboard.dart';
import 'package:intellihome_application/login_page.dart';


import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MaterialApp(home: LoginPage()));
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
