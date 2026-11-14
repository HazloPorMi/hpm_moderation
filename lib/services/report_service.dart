import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/report_model.dart';

/// Submits user/message reports to the top-level 'reports' Firestore collection.
///
/// Firestore structure:
///   reports/{reporterId}_{reportedUserId}_{messageId or "user"} → ReportModel
///
/// The id is deterministic, one report per reporter and target. The Firestore
/// rules (tenant isolation, 2026-11-14) let the reporter create it once and
/// never read it back: only admins read reports. So a repeat report is an
/// overwrite of an existing doc, which the rules refuse with
/// `permission-denied`; the caller treats that as "already reported".
///
/// A Cloud Function (onReportCreated) listens to this collection
/// and notifies the admin for 24hr moderation SLA.
class ReportService {
  ReportService._(this._firestoreOverride);

  static final ReportService instance = ReportService._(null);

  /// A service on [firestore] instead of the default instance (tests).
  @visibleForTesting
  factory ReportService.withFirestore(FirebaseFirestore firestore) => ReportService._(firestore);

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _firestore => _firestoreOverride ?? FirebaseFirestore.instance;

  /// The report's document id: `{reporterId}_{reportedUserId}_{messageId}`
  /// for a message report, `{reporterId}_{reportedUserId}_user` for a user
  /// report. Must match `reports/{reportId}` in firestore.rules.
  static String reportDocId({
    required String reporterId,
    required String reportedUserId,
    required ReportType type,
    String? messageId,
  }) {
    final target = type == ReportType.message ? messageId : 'user';
    return '${reporterId}_${reportedUserId}_$target';
  }

  /// Is [error] Firestore refusing a repeat report? With the deterministic id
  /// a second report of the same target is an update, and the rules deny it.
  static bool isAlreadyReported(Object error) =>
      error is FirebaseException && error.code == 'permission-denied';

  /// Submit a report for a message or user. Returns the report's document id.
  ///
  /// Throws an [ArgumentError] before writing when an id is blank (the rules
  /// would refuse it anyway), and a [FirebaseException] with code
  /// `permission-denied` when this reporter already reported this target
  /// (see [isAlreadyReported]).
  Future<String> submitReport({
    required String reporterId,
    required String reportedUserId,
    String? messageId,
    required ReportType type,
    required ReportReason reason,
    String? details,
  }) async {
    if (reporterId.trim().isEmpty) throw ArgumentError.value(reporterId, 'reporterId', 'must not be empty');
    if (reportedUserId.trim().isEmpty) throw ArgumentError.value(reportedUserId, 'reportedUserId', 'must not be empty');
    if (type == ReportType.message && (messageId == null || messageId.trim().isEmpty)) {
      throw ArgumentError.value(messageId, 'messageId', 'is required for a message report');
    }

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

    final id = reportDocId(
      reporterId: reporterId,
      reportedUserId: reportedUserId,
      type: type,
      messageId: messageId,
    );

    // A plain set (no merge): on an existing doc it is an update, which the
    // rules deny, so a repeat report never changes the first one.
    await _firestore.collection('reports').doc(id).set(report.toFirestore());
    return id;
  }
}
