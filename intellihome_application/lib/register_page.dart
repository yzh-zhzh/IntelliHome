import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'email_service.dart';
import 'otp_page.dart'; // We will create this standard OTP page next

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
  final _confirmPassCtrl = TextEditingController(); // NEW

  final AuthService _auth = AuthService();
  final EmailService _emailService = EmailService();
  
  bool _isLoading = false;
  bool _passwordsMatch = true; // For red border logic

  Future<void> _handleRegister() async {
    // 1. Check Empty Fields
    if (_nameCtrl.text.isEmpty || _uidCtrl.text.isEmpty || 
        _emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    // 2. Check Password Match
    if (_passCtrl.text != _confirmPassCtrl.text) {
      setState(() => _passwordsMatch = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Passwords do not match"),
          backgroundColor: Colors.red,
        )
      );
      return;
    } else {
      setState(() => _passwordsMatch = true);
    }

    // 3. Send OTP
    setState(() => _isLoading = true);
    
    String otp = _auth.generateOtp(); // This starts the 30min timer in AuthService
    bool sent = await _emailService.sendOtpEmail(_emailCtrl.text.trim(), otp);

    setState(() => _isLoading = false);

    if (sent) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("OTP Sent to Email!")));
      
      // Navigate to OTP Page
      if (!mounted) return;
      Navigator.push(
        context, 
        MaterialPageRoute(builder: (_) => OtpPage(
          email: _emailCtrl.text.trim(),
          correctOtp: otp,
          isRegistration: true,
          // Pass registration data to finish later
          regName: _nameCtrl.text.trim(),
          regUid: _uidCtrl.text.trim(),
          regPass: _passCtrl.text.trim(),
        ))
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to send Email.")));
    }
  }

  // Helper for Red Border Style
  InputDecoration _passDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      enabledBorder: _passwordsMatch 
          ? const OutlineInputBorder(borderSide: BorderSide(color: Colors.grey))
          : const OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
      focusedBorder: _passwordsMatch 
          ? const OutlineInputBorder(borderSide: BorderSide(color: Colors.blue, width: 2))
          : const OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _uidCtrl, decoration: const InputDecoration(labelText: "Create User ID", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            
            // Password Fields
            TextField(controller: _passCtrl, obscureText: true, decoration: _passDecoration("Password")),
            const SizedBox(height: 15),
            TextField(controller: _confirmPassCtrl, obscureText: true, decoration: _passDecoration("Confirm Password")),
            
            const SizedBox(height: 25),
            
            if (_isLoading)
              const CircularProgressIndicator()
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleRegister,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(15)),
                  child: const Text("Next: Verify Email", style: TextStyle(fontSize: 16)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}