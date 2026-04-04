import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_model.dart';

/// Submits user/message reports to the top-level 'reports' Firestore collection.
///
/// Firestore structure:
///   reports/{autoId} → ReportModel
///
/// A Cloud Function (onReportCreated) listens to this collection
/// and notifies the admin for 24hr moderation SLA.
class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Submit a report for a message or user.
  /// Returns the document ID of the created report.
  Future<String> submitReport({
    required String reporterId,
    required String reportedUserId,
    String? messageId,
    required ReportType type,
    required ReportReason reason,
    String? details,
  }) async {
    final report = ReportModel(
      reporterId: reporterId,
      reportedUserId: reportedUserId,
      messageId: messageId,
      type: type,
      reason: reason,
      details: details,
      status: ReportStatus.pending,
      createdAt: DateTime.now(),
    );

    final docRef = await _firestore
        .collection('reports')
        .add(report.toFirestore());

    return docRef.id;
  }

  /// Check if the current user already reported this message/user
  /// to prevent duplicate reports.
  Future<bool> hasAlreadyReported({
    required String reporterId,
    required String reportedUserId,
    String? messageId,
  }) async {
    var query = _firestore
        .collection('reports')
        .where('reporterId', isEqualTo: reporterId)
        .where('reportedUserId', isEqualTo: reportedUserId);

    if (messageId != null) {
      query = query.where('messageId', isEqualTo: messageId);
    }

    final snapshot = await query.limit(1).get();
    return snapshot.docs.isNotEmpty;
  }
}
