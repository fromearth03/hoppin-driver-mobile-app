import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import 'support_router.dart';

/// One ticket + its message thread — `GET /me/support-tickets/:id`. BOUND.
final driverTicketThreadProvider = FutureProvider.autoDispose
    .family<TicketThread, String>((ref, ticketId) {
  return ref.watch(supportRepositoryProvider).thread(ticketId);
});

/// The driver's ticket thread (PS-04) — BOUND end to end.
///
/// Everything here is real: the messages came from
/// `GET /me/support-tickets/:id` and a reply goes to
/// `POST /me/support-tickets/:id/messages`, where a person reads it. There is no
/// automated responder on the other end and this screen does not pretend there
/// is.
class DriverTicketScreen extends ConsumerStatefulWidget {
  /// Creates the thread view for [ticketId].
  const DriverTicketScreen({required this.ticketId, super.key});

  /// The ticket whose thread is shown.
  final String ticketId;

  @override
  ConsumerState<DriverTicketScreen> createState() => _DriverTicketScreenState();
}

class _DriverTicketScreenState extends ConsumerState<DriverTicketScreen> {
  final _replyCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _replyCtrl.text.trim();
    // An empty body posts NOTHING. A no-op request that looks like a send is a
    // reply the driver believes they made.
    if (body.isEmpty) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(supportRepositoryProvider).reply(
            ticketId: widget.ticketId,
            body: body,
          );
      _replyCtrl.clear();
      // The thread re-reads, so the driver sees their own message land from the
      // SERVER — not a locally-appended optimistic bubble that may not exist.
      ref.invalidate(driverTicketThreadProvider(widget.ticketId));
    } on Exception catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final threadAsync = ref.watch(driverTicketThreadProvider(widget.ticketId));

    final gutter = EdgeInsets.symmetric(
      horizontal: hoppin.spacing.gutter,
      vertical: hoppin.spacing.gutter,
    );
    final listPad = EdgeInsets.symmetric(
      horizontal: hoppin.spacing.md,
      vertical: hoppin.spacing.md,
    );

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HopTopBar(
              title: 'Ticket',
              // NEVER null — see DriverSupportScreen. A null back intent hides
              // the chevron and strands the driver on a nested screen.
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go(kDriverSupportRoute),
            ),
            Expanded(
              // ERROR IS ASKED FIRST — see the note on DriverSupportScreen.
              // Riverpod 3 keeps `isLoading` true on a failed future, so a
              // loading-first `.when` ladder would show the driver an endless
              // spinner when the call is down. A hang is a worse lie than an
              // error: the driver concludes support itself is broken.
              child: switch (threadAsync) {
                AsyncValue(:final error?) => ListView(
                    padding: gutter,
                    children: [
                      if (_isNotFound(error))
                        // A designed not-found state with a FORWARD EXIT. A
                        // ticket that is not ours (or no longer exists) is a
                        // dead end otherwise — and a dead end on a support
                        // screen is where a stuck driver gives up.
                        _TicketNotFound(
                          onBack: () => context.go(kDriverSupportRoute),
                        )
                      else
                        HopBanner.error(
                          message: friendlyErrorMessage(error),
                          actionLabel: 'Retry',
                          onAction: () => ref.invalidate(
                            driverTicketThreadProvider(widget.ticketId),
                          ),
                        ),
                    ],
                  ),
                AsyncValue(:final value?) => RefreshIndicator(
                    color: colors.accent,
                    backgroundColor: colors.card,
                    onRefresh: () async => ref.invalidate(
                      driverTicketThreadProvider(widget.ticketId),
                    ),
                    child: value.messages.isEmpty
                        ? ListView(
                            padding: gutter,
                            children: [
                              SizedBox(height: hoppin.spacing.lg),
                              const HopEmptyState(
                                compact: true,
                                headline: 'No replies yet',
                                supporting:
                                    'A person will pick this up and reply here.',
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: listPad,
                            itemCount: value.messages.length,
                            itemBuilder: (context, i) =>
                                _MessageBubble(message: value.messages[i]),
                          ),
                  ),
                _ => Center(
                    child: CircularProgressIndicator(color: colors.accent),
                  ),
              },
            ),
            Divider(height: 1, color: colors.hairline),
            _ReplyComposer(
              controller: _replyCtrl,
              sending: _sending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  /// Whether this failure is the contract's `404 NOT_FOUND` — the ticket does
  /// not exist, or is not this driver's.
  static bool _isNotFound(Object error) {
    final text = error.toString().toUpperCase();
    return text.contains('NOT_FOUND') || text.contains('404');
  }
}

/// The designed 404 state: the ticket is not ours, and there is a way onward.
class _TicketNotFound extends StatelessWidget {
  const _TicketNotFound({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;

    return Column(
      children: [
        SizedBox(height: hoppin.spacing.lg),
        const HopEmptyState(
          headline: "We can't find that ticket",
          supporting:
              'It may have been closed, or it belongs to another account.',
        ),
        SizedBox(height: hoppin.spacing.md),
        HopButton.primary(
          label: 'Back to my tickets',
          expand: true,
          onPressed: onBack,
        ),
      ],
    );
  }
}

/// The reply composer, pinned to the bottom (thumb zone).
class _ReplyComposer extends StatelessWidget {
  const _ReplyComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        hoppin.spacing.md,
        hoppin.spacing.sm,
        hoppin.spacing.md,
        hoppin.spacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('driverSupport.ticket.reply'),
              controller: controller,
              enabled: !sending,
              textCapitalization: TextCapitalization.sentences,
              style: hoppin.type.body.copyWith(color: colors.textHi),
              decoration: const InputDecoration(hintText: 'Write a reply…'),
              onSubmitted: (_) => onSend(),
            ),
          ),
          SizedBox(width: hoppin.spacing.sm),
          _SendButton(
            key: const Key('driverSupport.ticket.send'),
            sending: sending,
            onSend: onSend,
          ),
        ],
      ),
    );
  }
}

/// The send affordance — a token-styled accent circle, not a raw Material
/// icon button.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.sending, required this.onSend, super.key});

  final bool sending;
  final VoidCallback onSend;

  static const double _size = 48;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    return Semantics(
      button: true,
      label: 'Send',
      child: InkWell(
        onTap: sending ? null : onSend,
        borderRadius: BorderRadius.circular(hoppin.radii.pill),
        child: Container(
          height: _size,
          width: _size,
          decoration: BoxDecoration(
            color: sending ? colors.accentSubtle : colors.accent,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: sending
                ? SizedBox(
                    height: hoppin.spacing.md,
                    width: hoppin.spacing.md,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.accent,
                    ),
                  )
                : Icon(Icons.send, color: colors.onAccent, size: 20),
          ),
        ),
      ),
    );
  }
}

/// One message in the thread. Staff replies are labelled and visually distinct —
/// the driver should know when a human at Hoppin has spoken.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final TicketMessage message;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final mine = !message.isStaff;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: hoppin.spacing.xs),
        padding: EdgeInsets.symmetric(
          horizontal: hoppin.spacing.md,
          vertical: hoppin.spacing.sm,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: mine ? colors.accentSubtle : colors.card,
          borderRadius: BorderRadius.circular(hoppin.radii.card),
          border: Border.all(color: colors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isStaff)
              Text(
                'Hoppin support',
                style: hoppin.type.labelSmall.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            Text(
              message.body,
              style: hoppin.type.body.copyWith(color: colors.textHi),
            ),
            if (message.createdAt != null)
              Padding(
                padding: EdgeInsets.only(top: hoppin.spacing.xs),
                child: Text(
                  formatTime(message.createdAt!),
                  style: hoppin.type.metaSmall.copyWith(color: colors.textMid),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
