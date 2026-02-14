import 'package:flutter/material.dart';
import 'package:intellihome_application/services/auth_service.dart';
import 'package:intellihome_application/services/email_service.dart';
import 'otp_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameCtrl = TextEditingController();
  final _uidCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  final AuthService _auth = AuthService();
  final EmailService _emailService = EmailService();
  
  bool _isLoading = false;
  bool _passwordsMatch = true;

  Future<void> _handleRegister() async {
    // 1. Validation
    if (_nameCtrl.text.isEmpty || _uidCtrl.text.isEmpty || _emailCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fill all fields")));
      return;
    }

    if (_passCtrl.text != _confirmPassCtrl.text) {
      setState(() => _passwordsMatch = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    } else {
      setState(() => _passwordsMatch = true);
    }

    setState(() => _isLoading = true);
    
    // 2. Generate & Send OTP
    String otp = _auth.generateOtp();
    bool sent = await _emailService.sendOtpEmail(_emailCtrl.text.trim(), otp);

    setState(() => _isLoading = false);

    if (sent) {
      if(!mounted) return;
      // 3. Navigate to OTP Page (Pass the registration data to finish later)
      Navigator.push(
        context, 
        MaterialPageRoute(builder: (_) => OtpPage(
          email: _emailCtrl.text.trim(),
          correctOtp: otp,
          isRegistration: true,
          regName: _nameCtrl.text.trim(),
          regUid: _uidCtrl.text.trim(),
          regPass: _passCtrl.text.trim(),
        ))
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to send Email.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Account")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _uidCtrl, decoration: const InputDecoration(labelText: "Create User ID", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: "Email Address", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(
              controller: _passCtrl, 
              obscureText: true, 
              decoration: InputDecoration(
                labelText: "Password", 
                border: const OutlineInputBorder(),
                errorText: _passwordsMatch ? null : "Passwords do not match"
              )
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _confirmPassCtrl, 
              obscureText: true, 
              decoration: InputDecoration(
                labelText: "Confirm Password", 
                border: const OutlineInputBorder(),
                errorText: _passwordsMatch ? null : "Passwords do not match"
              )
            ),
            const SizedBox(height: 25),
            _isLoading 
              ? const CircularProgressIndicator()
              : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleRegister,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(15)),
                    child: const Text("Next: Verify Email"),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}