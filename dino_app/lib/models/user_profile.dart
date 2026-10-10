import 'package:cloud_firestore/cloud_firestore.dart';

enum AccountKind {
  standard,
  kid;

  static AccountKind fromWire(String? raw) =>
      raw == 'kid' ? AccountKind.kid : AccountKind.standard;
}

/// One `users/{uid}` document.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.createdAt,
    required this.friendCode,
    this.accountKind = AccountKind.standard,
    this.badgeCount = 0,
  });

  final String uid;
  final String displayName;
  final AccountKind accountKind;
  final DateTime createdAt;

  /// Denormalized count of `users/{uid}/badges` docs, for the PK gate.
  final int badgeCount;
  final String friendCode;

  /// Accepts a Firestore [Timestamp], a [DateTime], or an ISO-8601 string
  /// for [createdAt], so the same parser works for Firestore and JSON.
  factory UserProfile.fromJson(String uid, Map<String, dynamic> json) {
    return UserProfile(
      uid: uid,
      displayName: json['displayName'] as String? ?? '',
      accountKind: AccountKind.fromWire(json['accountKind'] as String?),
      createdAt: _parseTime(json['createdAt']),
      badgeCount: (json['badgeCount'] as num?)?.toInt() ?? 0,
      friendCode: json['friendCode'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'accountKind': accountKind.name,
        'createdAt': Timestamp.fromDate(createdAt),
        'badgeCount': badgeCount,
        'friendCode': friendCode,
      };

  static DateTime _parseTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    throw FormatException('Unsupported createdAt value: $value');
  }
}
