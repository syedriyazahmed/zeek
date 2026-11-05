import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../services/firebase/firebase_service.dart';
import '../models/user_model.dart';

abstract class AuthRepository {
  Future<UserModel?> getCurrentUser();
  Future<UserModel> signIn(String email, String password);
  Future<void> signOut();
  Stream<UserModel?> authStateChanges();
}

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseService _firebaseService;
  static const String _userPrefsKey = 'cached_current_user';

  FirebaseAuthRepository(this._firebaseService);

  @override
  Stream<UserModel?> authStateChanges() async* {
    if (_firebaseService.isInitialized && _firebaseService.auth != null) {
      yield* _firebaseService.auth!.authStateChanges().asyncMap((user) async {
        if (user == null) return null;
        return _fetchUserDoc(user.uid, user.email ?? '');
      });
    } else {
      // Local fallback stream
      yield await getCurrentUser();
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userPrefsKey);
      if (userJson != null) {
        final map = jsonDecode(userJson) as Map<String, dynamic>;
        return UserModel.fromMap(map, map['uid'] as String);
      }
    } catch (e) {
      debugPrint('[AuthRepository] Error getting cached user: $e');
    }
    return null;
  }

  @override
  Future<UserModel> signIn(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();

    // Check for demo / default credentials first for seamless verification
    final isDemoAdmin = cleanEmail.contains('admin');
    final role = isDemoAdmin ? AppConstants.roleAdmin : AppConstants.roleEmployee;
    final displayName = isDemoAdmin ? 'Shop Administrator' : 'Staff Sales Representative';

    UserModel userModel;

    if (_firebaseService.isInitialized && _firebaseService.auth != null) {
      try {
        final credential = await _firebaseService.auth!.signInWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        );
        final uid = credential.user!.uid;
        userModel = await _fetchUserDoc(uid, cleanEmail);
      } on FirebaseAuthException catch (e) {
        // If user not found in Firebase auth during testing, let's create or handle
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          try {
            final newCred = await _firebaseService.auth!.createUserWithEmailAndPassword(
              email: cleanEmail,
              password: password,
            );
            userModel = UserModel(
              uid: newCred.user!.uid,
              email: cleanEmail,
              displayName: displayName,
              role: role,
              shopId: AppConstants.defaultShopId,
              createdAt: DateTime.now(),
            );
            await _saveUserDoc(userModel);
          } catch (_) {
            rethrow;
          }
        } else {
          rethrow;
        }
      }
    } else {
      // Offline/Local mock user creation
      userModel = UserModel(
        uid: cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_'),
        email: cleanEmail,
        displayName: displayName,
        role: role,
        shopId: AppConstants.defaultShopId,
        createdAt: DateTime.now(),
      );
    }

    // Cache user locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userPrefsKey, jsonEncode(userModel.toMap()..['uid'] = userModel.uid));

    return userModel;
  }

  @override
  Future<void> signOut() async {
    if (_firebaseService.isInitialized && _firebaseService.auth != null) {
      await _firebaseService.auth!.signOut();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userPrefsKey);
  }

  Future<UserModel> _fetchUserDoc(String uid, String email) async {
    if (_firebaseService.firestore != null) {
      try {
        final doc = await _firebaseService.firestore!
            .collection('shops')
            .doc(AppConstants.defaultShopId)
            .collection('users')
            .doc(uid)
            .get();

        if (doc.exists && doc.data() != null) {
          return UserModel.fromMap(doc.data()!, uid);
        }
      } catch (e) {
        debugPrint('[AuthRepository] Notice fetching user doc: $e');
      }
    }

    final isDemoAdmin = email.contains('admin');
    return UserModel(
      uid: uid,
      email: email,
      displayName: isDemoAdmin ? 'Shop Administrator' : 'Staff Employee',
      role: isDemoAdmin ? AppConstants.roleAdmin : AppConstants.roleEmployee,
      shopId: AppConstants.defaultShopId,
      createdAt: DateTime.now(),
    );
  }

  Future<void> _saveUserDoc(UserModel user) async {
    if (_firebaseService.firestore != null) {
      try {
        await _firebaseService.firestore!
            .collection('shops')
            .doc(user.shopId)
            .collection('users')
            .doc(user.uid)
            .set(user.toMap(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('[AuthRepository] Notice saving user doc: $e');
      }
    }
  }
}

