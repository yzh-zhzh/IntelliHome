import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intellihome_application/services/auth_service.dart';
import 'package:intellihome_application/services/email_service.dart';
import 'login_page.dart';

class OtpPage extends StatefulWidget {
  final String email;
  final String correctOtp;
  final bool isRegistration;
  
  final String? regName;
  final String? regUid;
  final String? regPass;

  const OtpPage({
    super.key,
    required this.email,
    required this.correctOtp,
    required this.isRegistration,
    this.regName,
    this.regUid,
    this.regPass,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _otpCtrl = TextEditingController();
  final AuthService _auth = AuthService();
  final EmailService _emailService = EmailService();
  late String _currentOtp;
  
  Timer? _timer;
  int _start = 120;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _currentOtp = widget.correctOtp;
    _startTimer();
  }

  void _startTimer() {
    setState(() {
      _start = 120;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() {
          _canResend = true;
          timer.cancel();
        });
      } else {
        setState(() => _start--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _resend() async {
    String newOtp = _auth.generateOtp();
    bool sent = await _emailService.sendOtpEmail(widget.email, newOtp);
    if (sent) {
      setState(() => _currentOtp = newOtp);
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("New Code Sent!")));
    }
  }

  void _verify() async {
    if (!_auth.isOtpValid()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("OTP Expired. Resend new code.")));
      return;
    }

    if (_otpCtrl.text.trim() == _currentOtp) {
      
      if (widget.isRegistration) {
        try {
          await _auth.registerUser(
            widget.regName!, 
            widget.regUid!, 
            widget.email, 
            widget.regPass!
          );
          if(!mounted) return;
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account Created! Login now.")));
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      } else {
        try {
          Map<String, String> creds = await _auth.getCredentials(widget.email);
          if(!mounted) return;
          showDialog(
            context: context, 
            builder: (c) => AlertDialog(
              title: const Text("Account Recovered"),
              content: Text("Please write these down:\n\nUser ID: ${creds['userId']}\nPassword: ${creds['password']}"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false), 
                  child: const Text("Back to Login")
                )
              ],
            )
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Code")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verification")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text("Enter code sent to ${widget.email}"),
            const SizedBox(height: 20),
            TextField(
              controller: _otpCtrl,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(hintText: "######"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _verify, child: const Text("Verify")),
            TextButton(
              onPressed: _canResend ? _resend : null,
              child: Text(_canResend ? "Resend Code" : "Resend in $_start s"),
            )
          ],
        ),
      ),
    );
  }
}