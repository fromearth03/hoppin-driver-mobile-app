import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../data/models/support_ticket.dart';
import '../logic/ticket_thread_controller.dart';

/// A support ticket's conversation: the driver's messages on the right with
/// sent/read receipts, the team's on the left, quoted replies above the
/// bubble they answer. Long-press a message to quote it — the same mechanic
/// as the ride chat, so nothing here needs learning twice.
class TicketThreadScreen extends ConsumerStatefulWidget {
  final String ticketId;

  const TicketThreadScreen({super.key, required this.ticketId});

  @override
  ConsumerState<TicketThreadScreen> createState() =>
      _TicketThreadScreenState();
}

class _TicketThreadScreenState extends ConsumerState<TicketThreadScreen> {
  final _composer = TextEditingController();
  TicketMessage? _replyingTo;
  bool _sending = false;

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _composer.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    final result = await ref
        .read(ticketThreadControllerProvider(widget.ticketId).notifier)
        .send(body, replyToId: _replyingTo?.id);
    if (!mounted) return;
    setState(() => _sending = false);
    result.when(
      ok: (_) => setState(() {
        _composer.clear();
        _replyingTo = null;
      }),
      err: (e) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorCopy(e)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ticketThreadControllerProvider(widget.ticketId));
    final ticket = async.valueOrNull?.ticket;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          children: [
            Text(ticket?.subject ?? 'Support ticket',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.title.copyWith(fontSize: 20)),
            if (ticket != null) _statusLine(ticket),
          ],
        ),
      ),
      // SafeArea picks up the shell's extendBody inset, keeping the composer
      // above the floating tab pill.
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: async.when(
                loading: () => const AppLoading(),
                error: (e, _) => const AppEmptyState(
                    icon: Icons.forum_outlined,
                    title: "This ticket isn't available right now"),
                data: (thread) => thread.messages.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.forum_outlined,
                        title: 'No messages yet',
                        message:
                            'The support team will reply here — you can add '
                            'more detail any time.')
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: thread.messages.length,
                        itemBuilder: (_, i) => _bubble(thread
                            .messages[thread.messages.length - 1 - i]),
                      ),
              ),
            ),
            if (_replyingTo != null) _replyBanner(),
            _composerBar(),
          ],
        ),
      ),
    );
  }

  Widget _statusLine(SupportTicket ticket) {
    final (label, colour) = switch (ticket.status) {
      TicketStatus.resolved => ('Resolved', AppColors.positive),
      TicketStatus.rejected => ('Rejected', AppColors.negative),
      TicketStatus.pending => ('In progress', AppColors.accent),
      TicketStatus.open => ('Open', AppColors.info),
    };
    return Text(label,
        style: AppText.caption.copyWith(color: colour, fontSize: 12));
  }

  Widget _bubble(TicketMessage m) {
    final mine = m.isMine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => setState(() => _replyingTo = m),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78),
          decoration: BoxDecoration(
            color: mine ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
            border: mine ? null : Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (m.replyTo != null) _quote(m.replyTo!, mine),
              Text(
                m.body,
                style: AppText.body.copyWith(
                  color: mine ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('d MMM, HH:mm').format(m.createdAt.toLocal()),
                    style: AppText.caption.copyWith(
                      fontSize: 11,
                      color: mine
                          ? Colors.white.withValues(alpha: 0.75)
                          : AppColors.textDisabled,
                    ),
                  ),
                  // The server's receipt, only ever present on own messages:
                  // one check sent, two checks read by the team.
                  if (mine && m.status.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Icon(
                      m.isRead ? Icons.done_all : Icons.check,
                      size: 15,
                      color: m.isRead
                          ? const Color(0xFF7EE8C7)
                          : Colors.white.withValues(alpha: 0.75),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quote(TicketReplyPreview quoted, bool mine) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: BoxDecoration(
          color: mine
              ? Colors.white.withValues(alpha: 0.14)
              : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
                width: 3,
                color: mine ? Colors.white : AppColors.buttonPrimary),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              quoted.isStaff ? 'Support team' : 'You',
              style: AppText.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: mine ? Colors.white : AppColors.textSecondary,
              ),
            ),
            Text(
              quoted.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(
                color: mine
                    ? Colors.white.withValues(alpha: 0.85)
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );

  Widget _replyBanner() => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Replying to: ${_replyingTo!.body}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption,
              ),
            ),
            InkWell(
              onTap: () => setState(() => _replyingTo = null),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child:
                    Icon(Icons.close, size: 18, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );

  Widget _composerBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _composer,
                minLines: 1,
                maxLines: 4,
                style: AppText.body,
                decoration: InputDecoration(
                  hintText: 'Write a message...',
                  hintStyle:
                      AppText.body.copyWith(color: AppColors.textDisabled),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: AppColors.buttonPrimary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _sending ? null : _send,
                child: SizedBox(
                  height: 46,
                  width: 46,
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      );
}
