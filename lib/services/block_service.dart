import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/block_model.dart';

/// Manages user blocking with Firestore subcollection and local cache.
///
/// Firestore structure:
///   users/{currentUid}/blocked_users/{blockedUid} → BlockModel
///
/// Usage:
///   await BlockService.instance.init(currentUserUid);
///   bool blocked = BlockService.instance.isBlocked('someUid');
///   await BlockService.instance.blockUser(...);
class BlockService {
  BlockService._();
  static final BlockService instance = BlockService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentUid;
  final Set<String> _blockedUserIds = {};
  StreamSubscription<QuerySnapshot>? _subscription;

  /// Whether a given user ID is currently blocked.
  bool isBlocked(String uid) => _blockedUserIds.contains(uid);

  /// Unmodifiable view of currently blocked user IDs.
  Set<String> get blockedUserIds => Set.unmodifiable(_blockedUserIds);

  /// Initialize the block service for the current user.
  /// Sets up a realtime snapshot listener on the blocked_users subcollection.
  Future<void> init(String currentUid) async {
    if (_currentUid == currentUid && _subscription != null) return;

    await dispose();
    _currentUid = currentUid;

    _subscription = _blockedUsersRef()
        .snapshots()
        .listen((snapshot) {
      _blockedUserIds.clear();
      for (final doc in snapshot.docs) {
        _blockedUserIds.add(doc.id);
      }
    }, onError: (_) {
      // Graceful degradation — empty set means no filtering
    });

    // Initial load (synchronous wait for first snapshot)
    try {
      final snapshot = await _blockedUsersRef().get();
      _blockedUserIds.clear();
      for (final doc in snapshot.docs) {
        _blockedUserIds.add(doc.id);
      }
    } catch (_) {
      // Network unavailable — proceed with empty set
    }
  }

  /// Block a user. Writes to Firestore and updates local cache immediately.
  Future<void> blockUser({
    required String blockedUserId,
    String? blockedUserName,
  }) async {
    if (_currentUid == null) return;

    final block = BlockModel(
      blockedUserId: blockedUserId,
      blockedUserName: blockedUserName,
      blockedAt: DateTime.now(),
    );

    await _blockedUsersRef().doc(blockedUserId).set(block.toFirestore());
    _blockedUserIds.add(blockedUserId);
  }

  /// Unblock a user. Removes from Firestore and local cache.
  Future<void> unblockUser(String blockedUserId) async {
    if (_currentUid == null) return;

    await _blockedUsersRef().doc(blockedUserId).delete();
    _blockedUserIds.remove(blockedUserId);
  }

  /// Get all blocked users as BlockModel list (for settings screen).
  Future<List<BlockModel>> getBlockedUsers() async {
    if (_currentUid == null) return [];

    final snapshot = await _blockedUsersRef().get();
    return snapshot.docs.map((doc) => BlockModel.fromFirestore(doc)).toList();
  }

  /// Clean up listener when user logs out.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _blockedUserIds.clear();
    _currentUid = null;
  }

  CollectionReference _blockedUsersRef() {
    return _firestore
        .collection('users')
        .doc(_currentUid)
        .collection('blocked_users');
  }
}
