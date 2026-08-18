import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

final driverSosEventsProvider = FutureProvider.autoDispose<List<SosEvent>>((
  ref,
) {
  return ref.watch(safetyRepositoryProvider).myEvents();
});

/// Driver-facing SOS control. It uses the same `/me/sos` contract as the rider
/// so admin Safety Alerts receives both roles in one queue.
class DriverSafetyScreen extends ConsumerStatefulWidget {
  const DriverSafetyScreen({this.rideId, super.key});

  final String? rideId;

  @override
  ConsumerState<DriverSafetyScreen> createState() => _DriverSafetyScreenState();
}

class _DriverSafetyScreenState extends ConsumerState<DriverSafetyScreen> {
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _raise() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trigger emergency alert?'),
        content: const Text(
          'This sends an SOS to Hoppin safety staff. If you are in immediate danger, call 999 first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(safetyRepositoryProvider)
          .raiseSos(
            rideId: widget.rideId,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      _note.clear();
      ref.invalidate(driverSosEventsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS alert sent to Hoppin safety staff.'),
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final events = ref.watch(driverSosEventsProvider);
    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HopTopBar(
              title: 'Safety & emergency',
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/profile'),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(hoppin.spacing.gutter),
                children: [
                  HopCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(Icons.sos, size: 52, color: colors.error),
                        SizedBox(height: hoppin.spacing.sm),
                        Text(
                          'Need urgent help?',
                          textAlign: TextAlign.center,
                          style: hoppin.type.section.copyWith(
                            color: colors.textHi,
                          ),
                        ),
                        SizedBox(height: hoppin.spacing.xs),
                        Text(
                          'An SOS alerts Hoppin safety staff. It does not call emergency services.',
                          textAlign: TextAlign.center,
                          style: hoppin.type.bodySmall.copyWith(
                            color: colors.textMid,
                          ),
                        ),
                        SizedBox(height: hoppin.spacing.md),
                        TextField(
                          controller: _note,
                          enabled: !_busy,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'What happened? (optional)',
                            alignLabelWithHint: true,
                          ),
                        ),
                        SizedBox(height: hoppin.spacing.md),
                        HopButton.dangerOutline(
                          label: _busy ? 'Sending...' : 'Send SOS alert',
                          icon: Icons.sos,
                          expand: true,
                          onPressed: _busy ? null : _raise,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: hoppin.spacing.lg),
                  Text(
                    'Previous alerts',
                    style: hoppin.type.section.copyWith(color: colors.textHi),
                  ),
                  SizedBox(height: hoppin.spacing.sm),
                  events.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) =>
                        HopBanner.error(message: friendlyErrorMessage(e)),
                    data: (items) => items.isEmpty
                        ? Text(
                            'No SOS alerts raised.',
                            style: hoppin.type.bodySmall.copyWith(
                              color: colors.textMid,
                            ),
                          )
                        : Column(
                            children: [
                              for (final item in items)
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom: hoppin.spacing.sm,
                                  ),
                                  child: HopCard(
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.sos,
                                        color: item.status == 'resolved'
                                            ? colors.textMid
                                            : colors.error,
                                      ),
                                      title: Text(item.note ?? 'SOS alert'),
                                      subtitle: Text(item.status),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
