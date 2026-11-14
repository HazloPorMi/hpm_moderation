import 'package:cloud_firestore/cloud_firestore.dart';

class BlockModel {
  final String blockedUserId;
  final String? blockedUserName;
  /// Read from legacy docs only; never written (see [toFirestore]).
  final String? reason;
  final DateTime blockedAt;

  const BlockModel({
    required this.blockedUserId,
    this.blockedUserName,
    this.reason,
    required this.blockedAt,
  });

  /// The stored block. Never the [reason]: the blocked user may read their
  /// own entry (the chat checks it before sending), so it holds nothing
  /// private, and the Firestore rules refuse any other field.
  Map<String, dynamic> toFirestore() {
    return {
      'blockedUserId': blockedUserId,
      if (blockedUserName != null) 'blockedUserName': blockedUserName,
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
