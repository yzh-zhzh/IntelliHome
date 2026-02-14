import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // NEW: Store the logged-in User ID so we can fetch their profile later
  String? currentUserId; 

  // Track OTP Time
  DateTime? _otpGenerationTime;

  // --- OTP HELPERS ---
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

  // 1. LOGIN
  Future<bool> loginWithUserID(String userId, String password) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(userId).get();
      if (!doc.exists) throw "User ID not found!";

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      if (data['password'] == password) {
        currentUserId = userId; // <--- Save the ID!
        return true;
      } else {
        throw "Incorrect Password";
      }
    } catch (e) {
      rethrow;
    }
  }

  // 2. REGISTER
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
      // Auto-login after register
      currentUserId = userId;
    } catch (e) {
      rethrow;
    }
  }

  // 3. FETCH USER DETAILS (For Profile Page)
  Future<Map<String, dynamic>> getUserDetails() async {
    if (currentUserId == null) throw "No user logged in";
    DocumentSnapshot doc = await _db.collection('users').doc(currentUserId).get();
    return doc.data() as Map<String, dynamic>;
  }

  // 4. UPDATE PROFILE (Allows changing UserID and Email)
  Future<void> updateProfile(String newName, String newUserId, String newEmail) async {
    if (currentUserId == null) throw "No user logged in";

    // If User ID didn't change, just update fields
    if (newUserId == currentUserId) {
      await _db.collection('users').doc(currentUserId).update({
        'name': newName,
        'email': newEmail,
      });
    } else {
      // If User ID CHANGED, we must migrate the document
      // 1. Check if new ID is taken
      DocumentSnapshot newDoc = await _db.collection('users').doc(newUserId).get();
      if (newDoc.exists) throw "New User ID is already taken!";

      // 2. Get old data
      DocumentSnapshot oldDoc = await _db.collection('users').doc(currentUserId).get();
      Map<String, dynamic> data = oldDoc.data() as Map<String, dynamic>;

      // 3. Create new doc with updated info
      data['name'] = newName;
      data['email'] = newEmail;
      data['userId'] = newUserId;

      await _db.collection('users').doc(newUserId).set(data);

      // 4. Delete old doc
      await _db.collection('users').doc(currentUserId).delete();

      // 5. Update session
      currentUserId = newUserId;
    }
  }

  // 5. LOGOUT
  void logout() {
    currentUserId = null;
  }
  
  // ... (Keep existing isEmailRegistered and getCredentials methods) ...
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