import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/nav/app_shell.dart';

import '../../../app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../data/deletion_repository.dart';
import '../data/models/deletion_blocker.dart';
import 'widgets/settings_card.dart';

/// UK GDPR right to erasure. Irreversible, so it confirms first, and when
/// the server refuses it lists every blocker rather than one message.
///
/// Three things in the design have no backing and are not built:
///   * "Outstanding Balance is £124.00" — the blocker response carries codes
///     only, never an amount, so no figure is shown.
///   * "Clear Outstanding dues" — there is no settle-debt endpoint.
///   * "Temporary Deactivation" and its Deactivate button — there is no
///     deactivate path; only permanent deletion exists.
/// The warning panel and the single action keep the design's shape.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _busy = false;
  List<String> _blockers = const [];

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete your account?', style: AppText.title),
        content: const Text(
          'This erases your personal details and cannot be undone. Your trip '
          'and payment history is kept in an anonymised form, as the law requires.',
          style: AppText.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Keep my account',
                style: AppText.body.copyWith(color: AppColors.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.negative,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _blockers = const [];
    });
    final result = await ref.read(deletionRepositoryProvider).requestDeletion();
    if (!mounted) return;
    setState(() => _busy = false);

    result.when(
      ok: (_) => context.go(Routes.signIn),
      err: (e) {
        if (e.code == 'DELETION_BLOCKED') {
          setState(() => _blockers =
              ((e.fields['blockers'] as List?) ?? const [])
                  .map((b) => b as String)
                  .toList());
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: settingsAppBar(context, 'Delete Account'),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(
              top: 8, bottom: AppShell.bottomClearance),
          child: SettingsCard(
            title: 'Delete Account',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_blockers.isNotEmpty) ...[
                      // One panel per blocker, the same principle as the
                      // blocked-from-online list: a driver stopped by two
                      // things should see both at once.
                      ..._blockers.map(_blockerPanel),
                      const SizedBox(height: 20),
                    ],
                    const Text(
                      'Would you like to permanently delete your account?',
                      style: AppText.body,
                    ),
                    const SizedBox(height: 18),
                    _bullet(
                      'Permanent Deletion',
                      'Erase all rides history and your data. This cannot be '
                          'undone.',
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Spacer(),
                        SizedBox(
                          height: 62,
                          width: 170,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.negative,
                              disabledBackgroundColor:
                                  AppColors.negative.withValues(alpha: 0.5),
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w600),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _busy ? null : _confirmAndDelete,
                            child: const Text('Delete'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  /// The design's amber warning panel. The heading is the blocker's own
  /// copy — the server sends a code, never a balance — and there is no
  /// action button because nothing in the API can clear one from the app.
  Widget _blockerPanel(String code) {
    final copy = blockerCopy(code);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 24, color: AppColors.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Text(copy.title,
                    style: AppText.heading.copyWith(fontSize: 18)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(copy.body, style: AppText.bodySecondary),
          if (code == 'outstanding_balance') ...[
            const SizedBox(height: 8),
            // No endpoint settles a balance from the app, so this points at
            // the route that works instead of offering a button that cannot.
            const Text('Contact support to settle your balance.',
                style: AppText.caption),
          ],
        ],
      ),
    );
  }

  Widget _bullet(String title, String body) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 7, left: 4, right: 12),
                child: CircleAvatar(
                    radius: 3, backgroundColor: AppColors.textPrimary),
              ),
              Expanded(
                child: Text(title, style: AppText.heading.copyWith(fontSize: 18)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(body, style: AppText.body),
        ],
      );
}
