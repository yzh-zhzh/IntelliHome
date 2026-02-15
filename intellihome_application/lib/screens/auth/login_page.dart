import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:intellihome_application/screens/dashboard/home_dashboard.dart';
import 'package:intellihome_application/services/auth_service.dart';
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
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isLoading = false;
  
  String? _savedUserId;
  String? _savedUserName;
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    String? savedId = await _auth.getSavedUserId();
    if (savedId != null) {
      String name = await _auth.getUserName(savedId);
      bool bioEnabled = await _auth.isBiometricEnabled();
      bool deviceSupport = await _localAuth.canCheckBiometrics;

      setState(() {
        _savedUserId = savedId;
        _savedUserName = name;
        _canCheckBiometrics = bioEnabled && deviceSupport;
      });
    }
  }

  Future<void> _loginWithBiometrics() async {
    try {
      bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to login as $_savedUserName',
        options: const AuthenticationOptions(biometricOnly: true),
      );

      if (didAuthenticate) {
        setState(() => _isLoading = true);
        await _auth.loginDirectly(_savedUserId!);
        if(mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeDashboard()));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Biometric Error: $e")));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginStandard() async {
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

  void _switchAccount() async {
    await _auth.clearSession();
    setState(() {
      _savedUserId = null;
      _savedUserName = null;
      _uidCtrl.clear();
      _passCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center( 
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSmartHubLogo(),
                const SizedBox(height: 20),
                const Text("IntelliHome", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                const SizedBox(height: 40),
                
                if (_savedUserId != null) 
                  _buildWelcomeBackUI()
                else 
                  _buildStandardLoginUI(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBackUI() {
    return Column(
      children: [
        Text("Welcome back,", style: TextStyle(fontSize: 18, color: Colors.grey[600])),
        Text(_savedUserName ?? "User", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 30),

        if (_canCheckBiometrics) ...[
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: _loginWithBiometrics, 
              icon: const Icon(Icons.fingerprint, size: 28),
              label: const Text("Log in with Biometrics", style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent, 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 15),
          const Text("OR", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 15),
        ],

        SizedBox(
          width: double.infinity,
          height: 55,
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                 _uidCtrl.text = _savedUserId!;
                 _savedUserId = null; 
              });
            },
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: const BorderSide(color: Colors.blueAccent)
            ),
            child: const Text("Log in with Password", style: TextStyle(fontSize: 16)),
          ),
        ),
        
        const SizedBox(height: 25),
        TextButton(
          onPressed: _switchAccount,
          child: Text("Not $_savedUserName? Switch Account", style: const TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  Widget _buildStandardLoginUI() {
    return Column(
      children: [
        TextField(
          controller: _uidCtrl, 
          decoration: const InputDecoration(labelText: "User ID", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _passCtrl, 
          decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)), 
          obscureText: true
        ),
        const SizedBox(height: 25),
        
        if (_isLoading) const CircularProgressIndicator() else
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loginStandard, 
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              backgroundColor: Colors.blueAccent, 
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("LOGIN", style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 15),
        TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecoveryPage())), child: const Text("Forgot ID or Password?")),
        TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())), child: const Text("Create Account")),
      ],
    );
  }

  Widget _buildSmartHubLogo() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(height: 120, width: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.withOpacity(0.1))),
        const Icon(Icons.home_rounded, size: 80, color: Color(0xFF2A2D3E)),
        Positioned(top: 25, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]), child: const Icon(Icons.hub, size: 30, color: Colors.blueAccent))),
      ],
    );
  }
}