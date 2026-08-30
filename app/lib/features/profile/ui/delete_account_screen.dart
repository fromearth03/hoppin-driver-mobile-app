import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../data/deletion_repository.dart';
import '../data/models/deletion_blocker.dart';

/// UK GDPR right to erasure. Irreversible, so it confirms first, and when
/// the server refuses it lists every blocker rather than one message.
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
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This erases your personal details and cannot be undone. Your trip '
          'and payment history is kept in an anonymised form, as the law requires.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep my account'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            onPressed: () => Navigator.of(context).pop(true),
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
        appBar: AppBar(title: const Text('Delete account')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Deactivate or delete', style: AppText.title),
              const SizedBox(height: 16),
              const Text('Temporary deactivation', style: AppText.heading),
              const SizedBox(height: 4),
              const Text(
                "Hide your account for now. You won't receive ride offers, and your data is kept.",
                style: AppText.bodySecondary,
              ),
              const SizedBox(height: 16),
              const Text('Permanent deletion', style: AppText.heading),
              const SizedBox(height: 4),
              const Text(
                'Erase your personal details. This cannot be undone.',
                style: AppText.bodySecondary,
              ),
              if (_blockers.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  _blockers.length == 1
                      ? 'One thing to sort first'
                      : '${_blockers.length} things to sort first',
                  style: AppText.heading,
                ),
                const SizedBox(height: 8),
                // One row per blocker, the same principle as the
                // blocked-from-online list: a driver stopped by two things
                // should see both at once.
                ..._blockers.map((code) {
                  final copy = blockerCopy(code);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.negative.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(copy.title, style: AppText.body),
                        const SizedBox(height: 2),
                        Text(copy.body, style: AppText.caption),
                        if (code == 'outstanding_balance') ...[
                          const SizedBox(height: 10),
                          // No endpoint settles a balance from the app yet, so
                          // the action explains itself rather than pretending.
                          const OutlinedButton(
                            onPressed: null,
                            child: Text('Settle balance'),
                          ),
                          const SizedBox(height: 4),
                          const Text('Contact support to settle your balance.',
                              style: AppText.caption),
                        ],
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 32),
              // Deactivation has no endpoint yet. A button that looks live
              // and does nothing is worse than one that says why it cannot.
              const OutlinedButton(
                onPressed: null,
                child: Text('Deactivate'),
              ),
              const SizedBox(height: 4),
              const Text(
                'Temporary deactivation is handled by your operator — contact support to pause your account.',
                style: AppText.caption,
              ),
              const SizedBox(height: 12),
              FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.negative),
                onPressed: _busy ? null : _confirmAndDelete,
                child: const Text('Delete account'),
              ),
            ],
          ),
        ),
      );
}
