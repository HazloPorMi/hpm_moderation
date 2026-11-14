import 'package:flutter/material.dart';
import '../models/moderation_strings.dart';
import '../models/report_model.dart';
import '../services/report_service.dart';

/// Shows a report dialog for messages or users.
///
/// Returns true if report was submitted, false/null if cancelled.
Future<bool?> showReportDialog({
  required BuildContext context,
  required String reporterId,
  required String reportedUserId,
  required ReportType type,
  required ModerationStrings strings,
  String? messageId,
  @visibleForTesting ReportService? service,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _ReportDialogContent(
      reporterId: reporterId,
      reportedUserId: reportedUserId,
      type: type,
      messageId: messageId,
      strings: strings,
      service: service ?? ReportService.instance,
    ),
  );
}

class _ReportDialogContent extends StatefulWidget {
  final String reporterId;
  final String reportedUserId;
  final ReportType type;
  final String? messageId;
  final ModerationStrings strings;
  final ReportService service;

  const _ReportDialogContent({
    required this.reporterId,
    required this.reportedUserId,
    required this.type,
    this.messageId,
    required this.strings,
    required this.service,
  });

  @override
  State<_ReportDialogContent> createState() => _ReportDialogContentState();
}

class _ReportDialogContentState extends State<_ReportDialogContent> {
  ReportReason? _selectedReason;
  final _detailsController = TextEditingController();
  bool _isSubmitting = false;

  String _reasonLabel(ReportReason reason) {
    final s = widget.strings;
    switch (reason) {
      case ReportReason.spam:
        return s.reasonSpam;
      case ReportReason.harassment:
        return s.reasonHarassment;
      case ReportReason.inappropriateContent:
        return s.reasonInappropriate;
      case ReportReason.fraudScam:
        return s.reasonFraud;
      case ReportReason.other:
        return s.reasonOther;
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final title = widget.type == ReportType.message ? s.reportMessage : s.reportUser;

    return AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.selectReason, style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            ...ReportReason.values.map((reason) => RadioListTile<ReportReason>(
              title: Text(_reasonLabel(reason), style: const TextStyle(fontSize: 14)),
              value: reason,
              groupValue: _selectedReason,
              dense: true,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) => setState(() => _selectedReason = val),
            )),
            if (_selectedReason == ReportReason.other) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _detailsController,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: s.describeIssue,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: Text(s.cancel),
        ),
        ElevatedButton(
          onPressed: _selectedReason == null || _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(s.report, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_selectedReason == null) return;
    setState(() => _isSubmitting = true);

    final s = widget.strings;

    try {
      // No read-before-write: the reporter cannot read reports. The
      // deterministic id makes a repeat report a refused overwrite.
      await widget.service.submitReport(
        reporterId: widget.reporterId,
        reportedUserId: widget.reportedUserId,
        messageId: widget.messageId,
        type: widget.type,
        reason: _selectedReason!,
        details: _detailsController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.reportSubmitted)),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      if (ReportService.isAlreadyReported(e)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.alreadyReported)),
        );
        Navigator.of(context).pop(false);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${s.error}: $e')),
      );
      setState(() => _isSubmitting = false);
    }
  }
}
