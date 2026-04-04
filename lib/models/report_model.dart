import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportType { message, user }

enum ReportReason {
  spam,
  harassment,
  inappropriateContent,
  fraudScam,
  other;

  String get label {
    switch (this) {
      case ReportReason.spam:
        return 'Spam';
      case ReportReason.harassment:
        return 'Acoso / Harassment';
      case ReportReason.inappropriateContent:
        return 'Contenido inapropiado / Inappropriate Content';
      case ReportReason.fraudScam:
        return 'Fraude / Fraud or Scam';
      case ReportReason.other:
        return 'Otro / Other';
    }
  }
}

enum ReportStatus { pending, reviewed, resolved, dismissed }

class ReportModel {
  final String? id;
  final String reporterId;
  final String reportedUserId;
  final String? messageId;
  final ReportType type;
  final ReportReason reason;
  final String? details;
  final ReportStatus status;
  final DateTime createdAt;

  const ReportModel({
    this.id,
    required this.reporterId,
    required this.reportedUserId,
    this.messageId,
    required this.type,
    required this.reason,
    this.details,
    this.status = ReportStatus.pending,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      if (messageId != null) 'messageId': messageId,
      'type': type.name,
      'reason': reason.name,
      if (details != null && details!.isNotEmpty) 'details': details,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReportModel(
      id: doc.id,
      reporterId: data['reporterId'] ?? '',
      reportedUserId: data['reportedUserId'] ?? '',
      messageId: data['messageId'],
      type: ReportType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => ReportType.user,
      ),
      reason: ReportReason.values.firstWhere(
        (e) => e.name == data['reason'],
        orElse: () => ReportReason.other,
      ),
      details: data['details'],
      status: ReportStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ReportStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
