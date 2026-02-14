import 'package:flutter/material.dart';
import 'package:intellihome_application/services/auth_service.dart';
import 'package:intellihome_application/services/email_service.dart';
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

    // 1. Check if Email Exists in DB
    bool exists = await _auth.isEmailRegistered(_emailCtrl.text.trim());
    
    if (!exists) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email not found in database.")));
      return;
    }

    // 2. Send OTP
    String otp = _auth.generateOtp();
    bool sent = await _emailService.sendOtpEmail(_emailCtrl.text.trim(), otp);

    setState(() => _isLoading = false);

    if (sent) {
      if(!mounted) return;
      Navigator.push(
        context, 
        MaterialPageRoute(builder: (_) => OtpPage(
          email: _emailCtrl.text.trim(),
          correctOtp: otp,
          isRegistration: false, // Recovery Mode
        ))
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to send email.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recover Account")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Enter your registered email to retrieve your User ID and Password."),
            const SizedBox(height: 20),
            TextField(
              controller: _emailCtrl, 
              decoration: const InputDecoration(labelText: "Email Address", border: OutlineInputBorder())
            ),
            const SizedBox(height: 20),
            _isLoading 
              ? const CircularProgressIndicator()
              : SizedBox(
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