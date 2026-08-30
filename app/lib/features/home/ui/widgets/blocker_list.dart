import 'package:flutter/material.dart';

import '../../../../core/api/error_codes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/driver_status.dart';

/// What stands between the driver and going online, as a list rather than a
/// screen. `blocking_document_types` is an array — a driver blocked by three
/// documents should see all three at once, not discover them one re-upload
/// at a time.
class BlockerList extends StatelessWidget {
  final DriverStatus status;
  final void Function(String documentType)? onOpenDocument;
  final VoidCallback? onRegisterVehicle;
  final VoidCallback? onContactSupport;

  const BlockerList({
    super.key,
    required this.status,
    this.onOpenDocument,
    this.onRegisterVehicle,
    this.onContactSupport,
  });

  /// Indexed from one: the widget returns early when nothing is blocking,
  /// so a zero case cannot arise.
  static const _counts = ['', 'One', 'Two', 'Three', 'Four', 'Five'];

  /// `vehicle_insurance` becomes `Vehicle Insurance`. The tokens are a closed
  /// server enum, so title-casing them is safe — unlike prettifying free
  /// text, which is guesswork.
  static String documentLabel(String type) => type
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  @override
  Widget build(BuildContext context) {
    if (!status.isBlocked) return const SizedBox.shrink();

    final copy = notEligibleCopy(status.blockedReason!);
    final docs = status.blockingDocumentTypes;
    final rowCount = docs.isEmpty ? 1 : docs.length;
    final counter = rowCount < _counts.length ? _counts[rowCount] : '$rowCount';
    final noun = rowCount == 1 ? 'thing' : 'things';

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$counter $noun to sort before you can go online',
                style: AppText.heading),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              _row(title: copy.title, subtitle: copy.body, action: copy.action)
            else
              ...docs.map((d) => _row(
                    title: documentLabel(d),
                    subtitle: copy.body,
                    action: copy.action,
                    documentType: d,
                  )),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: onContactSupport,
                child: const Text('Contact support'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row({
    required String title,
    required String subtitle,
    required BlockedAction action,
    String? documentType,
  }) {
    final (icon, tint) = switch (action) {
      BlockedAction.none => (Icons.schedule, AppColors.warning),
      BlockedAction.contactSupport => (Icons.error_outline, AppColors.negative),
      _ => (Icons.priority_high, AppColors.negative),
    };

    // A row is tappable only when there is somewhere to go. Offering a tap
    // that does nothing teaches the driver the list is decorative.
    final onTap = switch (action) {
      BlockedAction.openDocuments when documentType != null =>
        () => onOpenDocument?.call(documentType),
      BlockedAction.registerVehicle => onRegisterVehicle,
      BlockedAction.contactSupport => onContactSupport,
      _ => null,
    };

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: tint),
      title: Text(title, style: AppText.body),
      subtitle: Text(
        action == BlockedAction.none ? '$subtitle · no action' : subtitle,
        style: AppText.caption,
      ),
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}
