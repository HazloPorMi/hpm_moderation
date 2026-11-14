import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hpm_moderation/hpm_moderation.dart';

void main() {
  final blockedAt = DateTime.utc(2026, 11, 14, 10);

  test('toFirestore never writes the reason (the blocked user can read the entry)', () {
    final data = BlockModel(blockedUserId: 'uidB', blockedUserName: 'Bruno', reason: 'rude', blockedAt: blockedAt).toFirestore();

    expect(data.keys.toSet(), {'blockedUserId', 'blockedUserName', 'blockedAt'});
    expect(data['blockedAt'], Timestamp.fromDate(blockedAt));
  });

  test('toFirestore only writes the fields the Firestore rules allow', () {
    final data = BlockModel(blockedUserId: 'uidB', blockedAt: blockedAt).toFirestore();

    expect(data.keys.toSet(), {'blockedUserId', 'blockedAt'});
  });

  test('fromFirestore still reads a legacy reason', () async {
    final db = FakeFirebaseFirestore();
    final ref = db.collection('users').doc('uidA').collection('blocked_users').doc('uidB');
    await ref.set({'blockedUserId': 'uidB', 'reason': 'legacy', 'blockedAt': Timestamp.fromDate(blockedAt)});

    final model = BlockModel.fromFirestore(await ref.get());
    expect(model.reason, 'legacy');
    expect(model.blockedUserId, 'uidB');
  });
}
