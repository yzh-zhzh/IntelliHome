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

  // --- LOGO BUILDER (From previous step) ---
  Widget _buildSmartHubLogo() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 120,
          width: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withOpacity(0.1),
          ),
        ),
        const Icon(Icons.home_rounded, size: 80, color: Color(0xFF2A2D3E)),
        Positioned(
          top: 25,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: const Icon(Icons.hub, size: 30, color: Colors.blueAccent),
          ),
        ),
      ],
    );
  }

  Future<void> _login() async {
    if (_uidCtrl.text.isEmpty || _passCtrl.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _auth.loginWithUserID(_uidCtrl.text.trim(), _passCtrl.text.trim());
      if(mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeDashboard()));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Failed: $e")));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // FIX IS HERE: Center + SingleChildScrollView prevents overflow
      body: Center( 
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSmartHubLogo(), // Using the new logo
                
                const SizedBox(height: 20),
                const Text("IntelliHome", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                const SizedBox(height: 40),
                
                TextField(
                  controller: _uidCtrl, 
                  decoration: const InputDecoration(
                    labelText: "User ID", 
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person)
                  )
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passCtrl, 
                  decoration: const InputDecoration(
                    labelText: "Password", 
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock)
                  ), 
                  obscureText: true
                ),
                
                const SizedBox(height: 25),
                
                if (_isLoading) 
                  const CircularProgressIndicator() 
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _login, 
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: Colors.blueAccent, // Optional styling
                        foregroundColor: Colors.white
                      ),
                      child: const Text("LOGIN", style: TextStyle(fontSize: 16)),
                    ),
                  ),
                
                const SizedBox(height: 15),

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
      ),
    );
  }
}