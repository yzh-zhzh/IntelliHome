import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  String? currentUserId; 

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

  Future<bool> loginWithUserID(String userId, String password) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(userId).get();
      if (!doc.exists) throw "User ID not found!";

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      if (data['password'] == password) {
        currentUserId = userId; 
        return true;
      } else {
        throw "Incorrect Password";
      }
    } catch (e) {
      rethrow;
    }
  }

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
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getUserDetails() async {
    if (currentUserId == null) throw "No user logged in";
    DocumentSnapshot doc = await _db.collection('users').doc(currentUserId).get();
    return doc.data() as Map<String, dynamic>;
  }

  Future<void> updateProfile(String newName, String newUserId, String newEmail) async {
    if (currentUserId == null) throw "No user logged in";

    if (newUserId == currentUserId) {
      await _db.collection('users').doc(currentUserId).update({
        'name': newName,
        'email': newEmail,
      });
    } else {
      DocumentSnapshot newDoc = await _db.collection('users').doc(newUserId).get();
      if (newDoc.exists) throw "New User ID is already taken!";

      DocumentSnapshot oldDoc = await _db.collection('users').doc(currentUserId).get();
      Map<String, dynamic> data = oldDoc.data() as Map<String, dynamic>;

      data['name'] = newName;
      data['email'] = newEmail;
      data['userId'] = newUserId;

      await _db.collection('users').doc(newUserId).set(data);

      await _db.collection('users').doc(currentUserId).delete();

      currentUserId = newUserId;
    }
  }

  void logout() {
    currentUserId = null;
  }
  
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