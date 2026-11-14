import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hpm_moderation/hpm_moderation.dart';

void main() {
  const reporter = 'uidAlice00000000000000000001';
  const reported = 'uidBruno00000000000000000002';

  group('reportDocId (must match reports/{reportId} in firestore.rules)', () {
    test('a message report is keyed on the message', () {
      expect(
        ReportService.reportDocId(reporterId: reporter, reportedUserId: reported, type: ReportType.message, messageId: 'm1'),
        '${reporter}_${reported}_m1',
      );
    });

    test('a user report is keyed on "user", even when a messageId is passed', () {
      expect(
        ReportService.reportDocId(reporterId: reporter, reportedUserId: reported, type: ReportType.user, messageId: 'm1'),
        '${reporter}_${reported}_user',
      );
    });

    test('a platform id works as the reported user', () {
      expect(ReportService.reportDocId(reporterId: reporter, reportedUserId: '66', type: ReportType.user), '${reporter}_66_user');
    });
  });

  group('submitReport', () {
    late FakeFirebaseFirestore db;
    late ReportService service;

    setUp(() {
      db = FakeFirebaseFirestore();
      service = ReportService.withFirestore(db);
    });

    test('writes the report under the deterministic id and returns it', () async {
      final id = await service.submitReport(
        reporterId: reporter,
        reportedUserId: reported,
        messageId: 'm1',
        type: ReportType.message,
        reason: ReportReason.harassment,
        details: 'insultos',
      );

      expect(id, '${reporter}_${reported}_m1');
      final data = (await db.collection('reports').doc(id).get()).data()!;
      expect(data.keys.toSet(), {'reporterId', 'reportedUserId', 'messageId', 'type', 'reason', 'details', 'status', 'createdAt'});
      expect(data['reporterId'], reporter);
      expect(data['reportedUserId'], reported);
      expect(data['type'], 'message');
      expect(data['reason'], 'harassment');
      expect(data['status'], 'pending');
      expect(data['createdAt'], isA<Timestamp>());
    });

    test('a user report omits empty details and never auto-generates an id', () async {
      final id = await service.submitReport(
        reporterId: reporter,
        reportedUserId: reported,
        type: ReportType.user,
        reason: ReportReason.spam,
        details: '',
      );

      final docs = (await db.collection('reports').get()).docs;
      expect(docs.map((d) => d.id), [id]);
      expect(id, '${reporter}_${reported}_user');
      expect(docs.single.data().containsKey('details'), isFalse);
    });

    test('refuses a message report without a messageId, writing nothing', () async {
      for (final messageId in [null, '', '  ']) {
        await expectLater(
          service.submitReport(reporterId: reporter, reportedUserId: reported, messageId: messageId, type: ReportType.message, reason: ReportReason.spam),
          throwsArgumentError,
        );
      }
      expect((await db.collection('reports').get()).docs, isEmpty);
    });

    test('refuses a blank reporter or reported user, writing nothing', () async {
      await expectLater(
        service.submitReport(reporterId: '', reportedUserId: reported, type: ReportType.user, reason: ReportReason.spam),
        throwsArgumentError,
      );
      await expectLater(
        service.submitReport(reporterId: reporter, reportedUserId: ' ', type: ReportType.user, reason: ReportReason.spam),
        throwsArgumentError,
      );
      expect((await db.collection('reports').get()).docs, isEmpty);
    });
  });

  group('isAlreadyReported', () {
    test('is true for the rules refusing the overwrite', () {
      expect(ReportService.isAlreadyReported(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied')), isTrue);
    });

    test('is false for any other failure', () {
      expect(ReportService.isAlreadyReported(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable')), isFalse);
      expect(ReportService.isAlreadyReported(ArgumentError('x')), isFalse);
      expect(ReportService.isAlreadyReported(Exception('permission-denied')), isFalse);
    });
  });
}
