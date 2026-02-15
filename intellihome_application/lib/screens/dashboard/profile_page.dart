import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:intellihome_application/screens/auth/login_page.dart';
import 'package:intellihome_application/services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _auth = AuthService();
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  final _nameCtrl = TextEditingController();
  final _uidCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  
  bool _isLoading = true;
  bool _isEditing = false; // Controls the text fields and save button
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      Map<String, dynamic> data = await _auth.getUserDetails();
      bool bioEnabled = await _auth.isBiometricEnabled();
      
      setState(() {
        _nameCtrl.text = data['name'] ?? '';
        _uidCtrl.text = data['userId'] ?? '';
        _emailCtrl.text = data['email'] ?? '';
        _isBiometricEnabled = bioEnabled;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // --- BIOMETRIC TOGGLE ---
  Future<void> _toggleBiometrics(bool value) async {
    if (value) {
      // Trying to ENABLE: Verify identity first
      bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Biometrics not available on this device.")));
        return;
      }

      try {
        bool didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'Please authenticate to enable biometric login',
          options: const AuthenticationOptions(biometricOnly: true),
        );

        if (didAuthenticate) {
          await _auth.setBiometricEnabled(true);
          setState(() => _isBiometricEnabled = true);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Biometric Login Enabled")));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } else {
      // DISABLING
      await _auth.setBiometricEnabled(false);
      setState(() => _isBiometricEnabled = false);
    }
  }

  // --- SAVE PROFILE ---
  Future<void> _handleUpdate() async {
    setState(() => _isLoading = true);
    try {
      await _auth.updateProfile(
        _nameCtrl.text.trim(),
        _uidCtrl.text.trim(),
        _emailCtrl.text.trim()
      );
      
      setState(() {
        _isLoading = false;
        _isEditing = false;
      });
      
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated Successfully")));
    } catch (e) {
      setState(() => _isLoading = false);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e")));
    }
  }

  void _handleLogout() {
    _auth.logout();
    Navigator.pushAndRemoveUntil(
      context, 
      MaterialPageRoute(builder: (_) => const LoginPage()), 
      (route) => false
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // --- PROFILE PICTURE & EDIT BUTTON ---
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.blue.shade100,
                  child: const Icon(Icons.person, size: 60, color: Colors.blue),
                ),
                // THE EDIT BUTTON
                GestureDetector(
                  onTap: () {
                     setState(() {
                        _isEditing = !_isEditing;
                        // If cancelling edit, reload original data
                        if (!_isEditing) _loadUserData(); 
                     });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Icon(
                      _isEditing ? Icons.close : Icons.edit, 
                      size: 20, 
                      color: Colors.blue
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Text(_nameCtrl.text, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text("IntelliHome Admin", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
            
            const SizedBox(height: 30),

            // --- TEXT FIELDS ---
            _buildTextField("Full Name", _nameCtrl, Icons.person),
            const SizedBox(height: 16),
            _buildTextField("User ID", _uidCtrl, Icons.badge),
            const SizedBox(height: 16),
            _buildTextField("Email Address", _emailCtrl, Icons.email),
            
            const SizedBox(height: 20),

            // --- BIOMETRIC SWITCH ---
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400) // Visible border
              ),
              child: SwitchListTile(
                title: const Text("Enable Biometrics"),
                subtitle: const Text("Log in with fingerprint/face"),
                secondary: const Icon(Icons.fingerprint, color: Colors.blue),
                value: _isBiometricEnabled,
                onChanged: _toggleBiometrics, // Always active for convenience
              ),
            ),
            
            const SizedBox(height: 30),

            // --- SAVE BUTTON (Only visible when editing) ---
            if (_isEditing)
              ElevatedButton(
                onPressed: _handleUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, 
                  foregroundColor: Colors.white, 
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Save Changes"),
              ),
            
            const SizedBox(height: 40),

            // --- LOGOUT BUTTON ---
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout),
                label: const Text("Log Out"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, IconData icon) {
    return TextField(
      controller: ctrl,
      enabled: _isEditing, // Controlled by the edit button
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blueGrey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: _isEditing ? Colors.white : Colors.grey.shade200,
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none
        ),
      ),
    );
  }
}