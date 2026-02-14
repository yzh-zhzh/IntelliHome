import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'email_service.dart';
import 'login_page.dart'; // To go back after success

class OtpPage extends StatefulWidget {
  final String email;
  final String correctOtp;
  final bool isRegistration;
  
  // Registration Data (only used if isRegistration = true)
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

  late String _currentValidOtp;
  
  // Timer State
  Timer? _timer;
  int _secondsRemaining = 120; // 2 Minutes
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _currentValidOtp = widget.correctOtp;
    _startTimer();
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 120;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resendOtp() async {
    // Generate new OTP & reset 30 min expiration
    String newOtp = _auth.generateOtp();
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sending new code...")));
    
    bool sent = await _emailService.sendOtpEmail(widget.email, newOtp);

    if (sent) {
      setState(() {
        _currentValidOtp = newOtp;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("New code sent!")));
      _startTimer(); // Restart 2 min timer
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to send. Try again.")));
    }
  }

  Future<void> _verify() async {
    // 1. Check 30-Minute Expiration
    if (!_auth.isOtpValid()) {
      showDialog(
        context: context, 
        builder: (c) => AlertDialog(
          title: const Text("Expired"),
          content: const Text("This code has expired (30 mins limit). Please resend a new one."),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))],
        )
      );
      return;
    }

    // 2. Check Code Match
    if (_otpCtrl.text.trim() == _currentValidOtp) {
      if (widget.isRegistration) {
        // Complete Registration
        try {
          await _auth.registerUser(
            widget.regName!, 
            widget.regUid!, 
            widget.email, 
            widget.regPass!
          );
          
          if(!mounted) return;
          // Go to Login
          Navigator.pushAndRemoveUntil(
            context, 
            MaterialPageRoute(builder: (_) => const LoginPage()), 
            (route) => false
          );
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account Created! Please Login.")));

        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Registration Error: $e")));
        }
      } else {
        // Recovery Flow (Just show success logic)
        try {
          String uid = await _auth.retrieveUserID(widget.email);
          await _auth.sendPasswordReset(widget.email);
          
          if(!mounted) return;
          showDialog(
            context: context, 
            builder: (c) => AlertDialog(
              title: const Text("Recovery Success"),
              content: Text("Your User ID is: $uid\n\nA password reset link has been sent to ${widget.email}."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context, 
                    MaterialPageRoute(builder: (_) => const LoginPage()), 
                    (route) => false
                  ), 
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid Code"), backgroundColor: Colors.red)
      );
    }
  }

  String get _timerText {
    int min = _secondsRemaining ~/ 60;
    int sec = _secondsRemaining % 60;
    return "${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verification")),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            Text("Enter the code sent to ${widget.email}", textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextField(
              controller: _otpCtrl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(hintText: "######"),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _verify,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(15)),
                child: const Text("Verify Code"),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _canResend ? _resendOtp : null,
              child: Text(
                _canResend ? "Resend Code" : "Resend in $_timerText",
                style: TextStyle(
                  color: _canResend ? Colors.blue : Colors.grey,
                  fontWeight: FontWeight.bold
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}