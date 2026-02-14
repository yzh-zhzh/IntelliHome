import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _auth = AuthService();
  
  final _nameCtrl = TextEditingController();
  final _uidCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  
  bool _isLoading = true;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      Map<String, dynamic> data = await _auth.getUserDetails();
      setState(() {
        _nameCtrl.text = data['name'] ?? '';
        _uidCtrl.text = data['userId'] ?? '';
        _emailCtrl.text = data['email'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

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
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated Successfully")));
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e")));
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
      backgroundColor: const Color(0xFFF5F5F5), // Light grey bg
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit, color: Colors.blue),
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
                if (!_isEditing) _loadUserData(); // Reset if cancelled
              });
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 16),
            
            Text(_nameCtrl.text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Text("IntelliHome User", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
            
            const SizedBox(height: 30),

            _buildTextField("Full Name", _nameCtrl, Icons.person),
            const SizedBox(height: 16),
            _buildTextField("User ID", _uidCtrl, Icons.badge),
            const SizedBox(height: 16),
            _buildTextField("Email Address", _emailCtrl, Icons.email),
            
            const SizedBox(height: 30),

            if (_isEditing)
              ElevatedButton(
                onPressed: _handleUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, 
                  foregroundColor: Colors.white, 
                  minimumSize: const Size(double.infinity, 50)
                ),
                child: const Text("Save Changes"),
              ),
            
            const SizedBox(height: 40),

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
      enabled: _isEditing,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: _isEditing ? Colors.white : Colors.grey[200],
      ),
    );
  }
}