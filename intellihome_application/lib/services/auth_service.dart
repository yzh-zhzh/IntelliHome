import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import this

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  String? currentUserId; 

  // --- EXISTING OTP LOGIC ---
  DateTime? _otpGenerationTime;
  String generateOtp() {
    var rng = Random();
    _otpGenerationTime = DateTime.now();
    return (rng.nextInt(900000) + 100000).toString();
  }
  bool isOtpValid() {
    if (_otpGenerationTime == null) return false;
    final difference = DateTime.now().difference(_otpGenerationTime!);
    return difference.inMinutes < 30; 
  }

  // --- AUTH FUNCTIONS ---

  // 1. STANDARD LOGIN (Password Check)
  Future<bool> loginWithUserID(String userId, String password) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(userId).get();
      if (!doc.exists) throw "User ID not found!";

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      if (data['password'] == password) {
        currentUserId = userId; 
        await _saveSession(userId); // <--- Remember User
        return true;
      } else {
        throw "Incorrect Password";
      }
    } catch (e) {
      rethrow;
    }
  }

  // 2. DIRECT LOGIN (For Biometrics - Skips Password Check)
  Future<bool> loginDirectly(String userId) async {
    try {
      // Still verify the user exists in DB
      DocumentSnapshot doc = await _db.collection('users').doc(userId).get();
      if (!doc.exists) throw "User not found";
      
      currentUserId = userId;
      await _saveSession(userId); // Refresh session
      return true;
    } catch (e) {
      rethrow;
    }
  }

  // 3. REGISTER
  Future<void> registerUser(String name, String userId, String email, String password) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) throw "User ID already taken!";

      await _db.collection('users').doc(userId).set({
        'name': name,
        'userId': userId,
        'email': email,
        'password': password,
        'createdAt': FieldValue.serverTimestamp(),
      });
      currentUserId = userId;
      await _saveSession(userId); // <--- Remember User
    } catch (e) {
      rethrow;
    }
  }

  // --- HELPER: Get Name for Login Page ---
  Future<String> getUserName(String userId) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.get('name') ?? "User";
      }
      return "User";
    } catch (e) {
      return "User";
    }
  }

  // --- SESSION MANAGEMENT (SharedPrefs) ---
  Future<void> _saveSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_user_id', userId);
  }

  Future<String?> getSavedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_user_id');
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_user_id');
    // We DO NOT remove 'biometric_enabled' here, 
    // because they might want to use it again when they log back in.
    currentUserId = null;
  }

  // --- BIOMETRIC PREFERENCES ---
  Future<void> setBiometricEnabled(bool isEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', isEnabled);
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled') ?? false;
  }

  // --- EXISTING HELPERS ---
  Future<Map<String, dynamic>> getUserDetails() async {
    if (currentUserId == null) throw "No user logged in";
    DocumentSnapshot doc = await _db.collection('users').doc(currentUserId).get();
    return doc.data() as Map<String, dynamic>;
  }

  Future<void> updateProfile(String newName, String newUserId, String newEmail) async {
    if (currentUserId == null) throw "No user logged in";
    // ... (Keep your existing update logic) ...
    // If ID changed, update session:
    if (newUserId != currentUserId) {
        // ... (Update Firestore logic) ...
        currentUserId = newUserId;
        await _saveSession(newUserId);
    } else {
        await _db.collection('users').doc(currentUserId).update({
          'name': newName, 'email': newEmail,
        });
    }
  }

  void logout() {
    // Note: We don't clear session here if we want to remember them.
    // But typically logout means "Sign out completely". 
    // However, for "Welcome Back" feature, we keep the ID in prefs but clear currentUserId.
    currentUserId = null; 
  }
  
  // ... (Keep isEmailRegistered and getCredentials) ...
  Future<bool> isEmailRegistered(String email) async {
    QuerySnapshot query = await _db.collection('users').where('email', isEqualTo: email).get();
    return query.docs.isNotEmpty;
  }
  Future<Map<String, String>> getCredentials(String email) async {
    QuerySnapshot query = await _db.collection('users').where('email', isEqualTo: email).get();
    if (query.docs.isEmpty) throw "Email not found";
    var data = query.docs.first.data() as Map<String, dynamic>;
    return {'userId': data['userId'], 'password': data['password']};
  }
}