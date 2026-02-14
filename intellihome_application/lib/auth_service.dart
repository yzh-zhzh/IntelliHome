import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  // Singleton pattern to ensure we track the SAME timestamp across screens
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Track OTP Time
  DateTime? _otpGenerationTime;

  // --- OTP HELPERS ---
  String generateOtp() {
    var rng = Random();
    // Reset timestamp whenever a new OTP is generated
    _otpGenerationTime = DateTime.now();
    return (rng.nextInt(900000) + 100000).toString();
  }

  bool isOtpValid() {
    if (_otpGenerationTime == null) return false;
    final difference = DateTime.now().difference(_otpGenerationTime!);
    return difference.inMinutes < 30; // Valid for 30 minutes
  }

  // --- AUTH FUNCTIONS ---

  // 1. LOGIN (Find Email via UserID)
  Future<User?> loginWithUserID(String userId, String password) async {
    try {
      QuerySnapshot query = await _db.collection('users').where('userId', isEqualTo: userId).get();
      if (query.docs.isEmpty) throw "User ID not found!";

      String email = query.docs.first.get('email');
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } catch (e) {
      rethrow;
    }
  }

  // 2. REGISTER
  Future<void> registerUser(String name, String userId, String email, String password) async {
    try {
      QuerySnapshot query = await _db.collection('users').where('userId', isEqualTo: userId).get();
      if (query.docs.isNotEmpty) throw "User ID already taken!";

      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      
      await _db.collection('users').doc(result.user!.uid).set({
        'name': name,
        'userId': userId,
        'email': email,
      });
    } catch (e) {
      rethrow;
    }
  }

  // 3. RECOVERY (Get UserID)
  Future<String> retrieveUserID(String email) async {
    try {
      QuerySnapshot query = await _db.collection('users').where('email', isEqualTo: email).get();
      if (query.docs.isEmpty) throw "Email not registered!";
      return query.docs.first.get('userId');
    } catch (e) {
      rethrow;
    }
  }

  // 4. RESET PASSWORD
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}