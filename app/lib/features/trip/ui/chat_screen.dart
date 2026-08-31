import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../data/models/ride_message.dart';
import '../logic/chat_controller.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String rideId;
  const ChatScreen({super.key, required this.rideId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  RideMessage? _replyingTo;
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    final result = await ref
        .read(chatControllerProvider(widget.rideId).notifier)
        .send(text, replyToId: _replyingTo?.id);
    if (!mounted) return;

    setState(() => _sending = false);
    result.when(
      ok: (_) {
        _input.clear();
        setState(() => _replyingTo = null);
      },
      // The driver's own words stay in the composer. Clearing it on a
      // failure tells them the rider was informed when they were not —
      // exactly wrong for a message sent while waiting at a pickup.
      err: (e) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorCopy(e)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(chatControllerProvider(widget.rideId));

    return Scaffold(
      appBar: AppBar(title: const Text('Message rider')),
      // SafeArea picks up the shell's extendBody inset, keeping the
      // composer above the floating tab pill rather than beneath it.
      body: SafeArea(
          child: Column(
        children: [
          Expanded(
            child: async.when(
              loading: () => const AppLoading(),
              error: (_, __) => const AppEmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: "Messages aren't available right now"),
              data: (messages) => messages.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.chat_bubble_outline,
                      title: 'No messages yet',
                      message: 'Send a note if you need to reach the rider.')
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (_, i) =>
                          _bubble(messages[messages.length - 1 - i]),
                    ),
            ),
          ),
          if (_replyingTo != null) _replyBanner(),
          _composer(),
        ],
      )),
    );
  }

  Widget _bubble(RideMessage m) => Align(
        alignment: m.isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () => setState(() => _replyingTo = m),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            constraints: const BoxConstraints(maxWidth: 290),
            decoration: BoxDecoration(
              // The design gives the driver's own messages the brand
              // orange and the rider's a plain white card.
              color: m.isMine ? AppColors.accent : AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: m.isMine
                  ? null
                  : Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (m.replyToBody != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(m.replyToBody!,
                        style: AppText.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                Text(
                  m.body,
                  style: AppText.body.copyWith(
                      fontSize: 16,
                      color: m.isMine ? Colors.white : AppColors.textPrimary),
                ),
                if (m.isMine)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      m.status == MessageStatus.read
                          ? Icons.done_all
                          : Icons.done,
                      size: 14,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  Widget _replyBanner() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: AppColors.background,
        child: Row(
          children: [
            Expanded(
              child: Text('Replying to: ${_replyingTo!.body}',
                  style: AppText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _replyingTo = null),
            ),
          ],
        ),
      );

  Widget _composer() => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  enabled: !_sending,
                  decoration: const InputDecoration(
                      hintText: 'Message', border: OutlineInputBorder()),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.send),
                onPressed: _sending ? null : _send,
              ),
            ],
          ),
        ),
      );
}
