import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'home_dashboard.dart';
import 'register_page.dart';
import 'recovery_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _uidCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final AuthService _auth = AuthService();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      await _auth.loginWithUserID(_uidCtrl.text, _passCtrl.text);
      if(mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeDashboard()));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Failed: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.home, size: 80, color: Colors.blue),
              const Text("IntelliHome", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              
              TextField(controller: _uidCtrl, decoration: const InputDecoration(labelText: "User ID", border: OutlineInputBorder())),
              const SizedBox(height: 15),
              TextField(controller: _passCtrl, decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()), obscureText: true),
              
              const SizedBox(height: 25),
              _isLoading 
                ? const CircularProgressIndicator() 
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(onPressed: _login, child: const Text("LOGIN")),
                  ),
              
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecoveryPage())),
                child: const Text("Forgot ID or Password?"),
              ),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
                child: const Text("Create Account"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}