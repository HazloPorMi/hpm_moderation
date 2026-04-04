import 'package:flutter/material.dart';
import '../models/block_model.dart';
import '../models/moderation_strings.dart';
import '../services/block_service.dart';

/// A screen that displays the list of blocked users with unblock option.
class BlockedUsersScreen extends StatefulWidget {
  final ModerationStrings strings;

  const BlockedUsersScreen({super.key, required this.strings});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<BlockModel> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final users = await BlockService.instance.getBlockedUsers();
      if (mounted) setState(() { _blockedUsers = users; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return Scaffold(
      appBar: AppBar(title: Text(s.blockedUsers)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(s.noBlockedUsers, textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  ),
                )
              : ListView.builder(
                  itemCount: _blockedUsers.length,
                  itemBuilder: (context, index) {
                    final blocked = _blockedUsers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[300],
                        child: Text((blocked.blockedUserName ?? '?')[0].toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      title: Text(blocked.blockedUserName ?? blocked.blockedUserId),
                      subtitle: Text('${s.blockedOn} ${_formatDate(blocked.blockedAt)}',
                        style: const TextStyle(fontSize: 12)),
                      trailing: TextButton(
                        onPressed: () => _unblockUser(blocked),
                        child: Text(s.unblockUser, style: const TextStyle(color: Colors.red)),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _unblockUser(BlockModel blocked) async {
    final s = widget.strings;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.unblockUser),
        content: Text('${blocked.blockedUserName ?? ''} ${s.canMessageAgain}'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(s.unblockUser, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await BlockService.instance.unblockUser(blocked.blockedUserId);
        if (mounted) {
          setState(() => _blockedUsers.removeWhere((b) => b.blockedUserId == blocked.blockedUserId));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.unblockedSuccessfully)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${s.error}: $e')));
        }
      }
    }
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}
