import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final DateTime createdAt;
  final Map<String, dynamic> preferences;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.createdAt,
    this.preferences = const {},
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      preferences: json['preferences'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'preferences': preferences,
    };
  }
}
