import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'email_service.dart';
import 'otp_page.dart';

class RecoveryPage extends StatefulWidget {
  const RecoveryPage({super.key});

  @override
  State<RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends State<RecoveryPage> {
  final _emailCtrl = TextEditingController();
  final AuthService _auth = AuthService();
  final EmailService _emailService = EmailService();
  bool _isLoading = false;

  Future<void> _sendOtp() async {
    if (_emailCtrl.text.isEmpty) return;

    setState(() => _isLoading = true);

    // Generate & Send
    String otp = _auth.generateOtp();
    bool result = await _emailService.sendOtpEmail(_emailCtrl.text.trim(), otp);

    setState(() => _isLoading = false);

    if (result) {
      if(!mounted) return;
      // Navigate to Shared OTP Page
      Navigator.push(
        context, 
        MaterialPageRoute(builder: (_) => OtpPage(
          email: _emailCtrl.text.trim(),
          correctOtp: otp,
          isRegistration: false, // Flag for recovery flow
        ))
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to send email.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Account Recovery")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Enter your registered email to recover your User ID and Password."),
            const SizedBox(height: 20),
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: "Email Address", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            
            if (_isLoading)
              const CircularProgressIndicator()
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sendOtp,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(15)),
                  child: const Text("Send Verification Code"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}