import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'access_level.dart';

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final DateTime createdAt;
  final Map<String, dynamic> preferences;
  final AccessLevel accessLevel;
  final bool isApproved;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? pendingApprovalOtp;
  final DateTime? otpGeneratedAt;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.createdAt,
    this.preferences = const {},
    this.accessLevel = AccessLevel.pending,
    this.isApproved = false,
    this.approvedAt,
    this.approvedBy,
    this.pendingApprovalOtp,
    this.otpGeneratedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    debugPrint('🔍 UserModel.fromJson - raw data: $json');
    final model = UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      preferences: json['preferences'] as Map<String, dynamic>? ?? {},
      accessLevel:
          AccessLevelExtension.fromString(json['accessLevel'] as String?),
      isApproved: json['isApproved'] as bool? ?? false,
      approvedAt: (json['approvedAt'] as Timestamp?)?.toDate(),
      approvedBy: json['approvedBy'] as String?,
      pendingApprovalOtp: json['pendingApprovalOtp'] as String?,
      otpGeneratedAt: (json['otpGeneratedAt'] as Timestamp?)?.toDate(),
    );
    debugPrint(
        '🔍 UserModel.fromJson - parsed displayName: ${model.displayName}');
    debugPrint(
        '🔍 UserModel.fromJson - accessLevel: ${model.accessLevel.displayName}');
    return model;
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'preferences': preferences,
      'accessLevel': accessLevel.toStorageString(),
      'isApproved': isApproved,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
      'pendingApprovalOtp': pendingApprovalOtp,
      'otpGeneratedAt':
          otpGeneratedAt != null ? Timestamp.fromDate(otpGeneratedAt!) : null,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    DateTime? createdAt,
    Map<String, dynamic>? preferences,
    AccessLevel? accessLevel,
    bool? isApproved,
    DateTime? approvedAt,
    String? approvedBy,
    String? pendingApprovalOtp,
    DateTime? otpGeneratedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      preferences: preferences ?? this.preferences,
      accessLevel: accessLevel ?? this.accessLevel,
      isApproved: isApproved ?? this.isApproved,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      pendingApprovalOtp: pendingApprovalOtp ?? this.pendingApprovalOtp,
      otpGeneratedAt: otpGeneratedAt ?? this.otpGeneratedAt,
    );
  }

  /// Check if user can access the main app features
  bool get canAccessApp => isApproved && accessLevel.isApproved;

  /// Check if user is an admin
  bool get isAdmin => accessLevel == AccessLevel.high;

  /// Check if user can approve other users
  bool get canApproveUsers => accessLevel.canApproveUsers;
}
