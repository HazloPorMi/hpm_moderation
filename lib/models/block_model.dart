import 'package:cloud_firestore/cloud_firestore.dart';

class BlockModel {
  final String blockedUserId;
  final String? blockedUserName;
  final String? reason;
  final DateTime blockedAt;

  const BlockModel({
    required this.blockedUserId,
    this.blockedUserName,
    this.reason,
    required this.blockedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'blockedUserId': blockedUserId,
      if (blockedUserName != null) 'blockedUserName': blockedUserName,
      if (reason != null) 'reason': reason,
      'blockedAt': Timestamp.fromDate(blockedAt),
    };
  }

  factory BlockModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BlockModel(
      blockedUserId: data['blockedUserId'] ?? doc.id,
      blockedUserName: data['blockedUserName'],
      reason: data['reason'],
      blockedAt: (data['blockedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
