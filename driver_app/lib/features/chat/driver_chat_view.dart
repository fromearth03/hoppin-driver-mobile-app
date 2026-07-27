import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../motion/widgets/typing_locked_in_motion.dart';
import 'driver_chat_builder.dart';
import 'driver_chat_interactor.dart';
import 'widgets/driver_chat_bubble.dart';
import 'widgets/driver_chat_closed_state.dart';
import 'widgets/driver_chat_templates.dart';

/// The driver's chat surface — thread, templates-first, motion-locked composer.
/// Laid out from `Home - Active Trip (chat).jpg`; dark theme is PRIMARY (SF-02).
///
/// With voice at #45 (never dials), this is the ONLY pickup-coordination channel
/// the driver has.
class DriverChatView extends ConsumerStatefulWidget {
  /// Creates the chat surface for [rideId].
  const DriverChatView({required this.rideId, super.key});

  /// The ride whose thread this surface reads and writes.
  final String rideId;

  @override
  ConsumerState<DriverChatView> createState() => _DriverChatViewState();
}

class _DriverChatViewState extends ConsumerState<DriverChatView> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// THE ONE send path from the view. The composer and every template chip both
  /// call it, so a chip gets byte-identical CHAT_CLOSED handling.
  ///
  /// [fromComposer] clears the field on dispatch — a template never touches it.
  /// The interactor's `send` no-ops on empty/whitespace and after a close, so
  /// clearing eagerly here is safe: the body has already been handed off.
  void _send(String body, {bool fromComposer = false}) {
    ref.read(driverChatInteractorProvider.notifier).send(widget.rideId, body);
    if (fromComposer && body.trim().isNotEmpty) _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chrome = context.hoppin.chrome;
    final rideId = widget.rideId;
    final messagesAsync = ref.watch(driverChatStreamProvider(rideId));
    final myId = ref.watch(authServiceProvider).userId;
    final chatState = ref.watch(driverChatInteractorProvider);

    // Surface a TRANSIENT send failure as a snackbar — CHAT_CLOSED never lands
    // here (it is terminal), so this is only ever a retryable hiccup.
    ref.listen(driverChatInteractorProvider.select((s) => s.error), (_, err) {
      if (err != null && err.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(err)));
      }
    });

    // 🔴 THE THREAD RUNS UNDER THE PILL; THE COMPOSER DOES NOT.
    //
    // This was a Column — bar, thread, composer — which meant the bar's
    // BackdropFilter had nothing painted beneath it to sample and its "glass"
    // was a tinted box (see HopGlass's note; it photographs fine, which is how
    // it shipped).
    //
    // Only the TOP bar lifts into the Stack. The composer stays in flow on
    // purpose: it is anchored to the keyboard, and a text field floated over its
    // own scroll view is how you get a cursor hidden behind a bar. Glass earns
    // its place over CONTENT THAT MOVES — the thread does, the composer never.
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              // The thread must clear the pill it now scrolls under. The
              // composer sits below the thread, so it needs no such room.
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: messagesAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                        child: Padding(
                          padding: EdgeInsets.all(
                            context.hoppin.spacing.gutter,
                          ),
                          child: HopBanner.error(
                            message: friendlyErrorMessage(e),
                          ),
                        ),
                      ),
                      data: (messages) => messages.isEmpty
                          ? Center(
                              child: Text(
                                'Say hello — messages stay between you and '
                                'your rider.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ListView.builder(
                              reverse: true, // newest pinned to the bottom
                              // 🔴 The thread scrolls UNDER the pill now, so
                              // the room it owes the bar goes at its TOP —
                              // which on a reversed list is `bottom`, since
                              // reverse flips the axis. Get this the intuitive
                              // way round and the oldest message is the one
                              // that ends up unreachable.
                              padding: EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                16 + chrome.scrollPaddingTop,
                              ),
                              itemCount: messages.length,
                              itemBuilder: (context, i) {
                                final m = messages[messages.length - 1 - i];
                                return DriverChatBubble(
                                  message: m,
                                  mine: m.senderId == myId,
                                );
                              },
                            ),
                    ),
                  ),
                  const Divider(height: 1),
                  // The send surface. Once the server answers `409 CHAT_CLOSED`
                  // it is REPLACED — composer AND chips both leave the tree — by
                  // the terminal panel, which carries a forward exit. The thread
                  // above stays read.
                  if (chatState.chatClosed)
                    DriverChatClosedState(
                      onExit: () => context.canPop()
                          ? context.pop()
                          : context.go('/trip/$rideId'),
                    )
                  else ...[
                    // 🔴 TEMPLATES FIRST, AND OUTSIDE THE LOCK. They stay live
                    // at 30 mph — a one-tap chip is legal from a cradle and is
                    // the entire reason the keyboard is never needed at speed.
                    DriverChatTemplates(onSend: _send),

                    // 🔴 THE COMPOSER, AND ONLY THE COMPOSER, IS LOCKED IN
                    // MOTION. TypingLockedInMotion REMOVES it from the tree — a
                    // disabled TextField is still a TextField. The chips above
                    // are NOT wrapped.
                    TypingLockedInMotion(
                      child: _Composer(
                        controller: _ctrl,
                        sending: chatState.sending,
                        onSend: () => _send(_ctrl.text, fromComposer: true),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Above the thread. Unconditional back: reached with `context.go`,
          // canPop() is false, and a stock bar draws no arrow — the rider
          // shipped exactly this bug and stranded the user on a moving-car chat
          // screen. Pop when there is a stack, else return to the trip.
          //
          // 🔴 POSITIONED, NOT Align. A non-positioned `Align` is sized to the
          // whole Stack, so it hit-tests the entire screen and — sitting above
          // the content — silently eats every tap on the thread and the composer
          // below it. It looks perfect and is dead to the touch. Binding it to
          // `top/left/right` lets it intercept only where it paints.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: HopTopBar(
              title: 'Message your rider',
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/trip/$rideId'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !sending,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Message…'),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            tooltip: 'Send',
          ),
        ],
      ),
    );
  }
}
