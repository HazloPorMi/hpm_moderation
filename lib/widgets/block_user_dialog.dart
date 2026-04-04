import 'package:flutter/material.dart';
import '../models/moderation_strings.dart';
import '../services/block_service.dart';

/// Shows a confirmation dialog to block a user, then executes the block.
///
/// Returns true if user was blocked, false/null if cancelled.
Future<bool?> showBlockUserDialog({
  required BuildContext context,
  required String blockedUserId,
  required ModerationStrings strings,
  String? blockedUserName,
}) async {
  final displayName = blockedUserName ?? '';

  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(strings.blockConfirmTitle),
      content: Text(
        '$displayName\n\n${strings.blockConfirmBody}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(strings.cancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: Text(strings.blockUser, style: const TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  if (confirm != true) return false;

  try {
    await BlockService.instance.blockUser(
      blockedUserId: blockedUserId,
      blockedUserName: blockedUserName,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.blockedSuccessfully)),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${strings.error}: $e')),
      );
    }
    return false;
  }
}
