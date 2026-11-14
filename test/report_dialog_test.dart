import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hpm_moderation/hpm_moderation.dart';

const _strings = ModerationStrings(
  reportMessage: 'Report message',
  reportUser: 'Report user',
  blockUser: 'Block',
  unblockUser: 'Unblock',
  blockedUsers: 'Blocked users',
  blockConfirmTitle: 'Block?',
  blockConfirmBody: 'Sure?',
  blockedSuccessfully: 'Blocked',
  unblockedSuccessfully: 'Unblocked',
  reportSubmitted: 'REPORT SUBMITTED',
  alreadyReported: 'ALREADY REPORTED',
  selectReason: 'Select a reason',
  reasonSpam: 'Spam',
  reasonHarassment: 'Harassment',
  reasonInappropriate: 'Inappropriate',
  reasonFraud: 'Fraud',
  reasonOther: 'Other',
  describeIssue: 'Describe',
  noBlockedUsers: 'None',
  blockedOn: 'Blocked on',
  canMessageAgain: 'Can message again',
  cancel: 'Cancel',
  report: 'Report',
  yes: 'Yes',
  no: 'No',
  error: 'ERROR',
);

/// Records the submission and answers with [outcome]: an id, or a thrown error.
class _FakeReportService implements ReportService {
  _FakeReportService(this.outcome);

  final Object outcome;
  final List<Map<String, Object?>> calls = [];

  @override
  Future<String> submitReport({
    required String reporterId,
    required String reportedUserId,
    String? messageId,
    required ReportType type,
    required ReportReason reason,
    String? details,
  }) async {
    calls.add({'reporterId': reporterId, 'reportedUserId': reportedUserId, 'messageId': messageId, 'type': type, 'reason': reason});
    if (outcome is String) return outcome as String;
    throw outcome;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<bool?> _openAndSubmit(WidgetTester tester, _FakeReportService service) async {
  bool? result;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showReportDialog(
              context: context,
              reporterId: 'uidA',
              reportedUserId: 'uidB',
              type: ReportType.message,
              messageId: 'm1',
              strings: _strings,
              service: service,
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Spam'));
  await tester.pump();
  await tester.tap(find.text('Report'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('submits once, with no duplicate pre-check read, and confirms', (tester) async {
    final service = _FakeReportService('uidA_uidB_m1');

    final result = await _openAndSubmit(tester, service);

    expect(service.calls, hasLength(1));
    expect(service.calls.single, {'reporterId': 'uidA', 'reportedUserId': 'uidB', 'messageId': 'm1', 'type': ReportType.message, 'reason': ReportReason.spam});
    expect(find.text('REPORT SUBMITTED'), findsOneWidget);
    expect(result, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a permission-denied write is "already reported", not an error', (tester) async {
    final service = _FakeReportService(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'));

    final result = await _openAndSubmit(tester, service);

    expect(find.text('ALREADY REPORTED'), findsOneWidget);
    expect(find.textContaining('ERROR'), findsNothing);
    expect(result, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('any other failure shows the error and keeps the dialog open to retry', (tester) async {
    final service = _FakeReportService(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));

    await _openAndSubmit(tester, service);

    expect(find.textContaining('ERROR'), findsOneWidget);
    expect(find.text('ALREADY REPORTED'), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
    // The button is enabled again for a retry.
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNotNull);
  });
}
