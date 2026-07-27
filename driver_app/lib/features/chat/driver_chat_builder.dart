import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'driver_chat_interactor.dart';
import 'driver_chat_state.dart';
import 'driver_chat_view.dart';

/// Assembly point of the chat riblet (DOCS/05): declares the interactor's
/// provider so the view and the router both import the builder, never each
/// other.
///
/// NOT autoDispose. The interactor holds the terminal `chatClosed` latch and the
/// in-flight `sending` guard; a disposed interactor would forget a permanent
/// close the moment the driver glanced away and came back. (The polling THREAD
/// is autoDispose — that read should stop when nobody is watching — but the send
/// state must persist for the life of the surface.)
final driverChatInteractorProvider =
    NotifierProvider<DriverChatInteractor, DriverChatState>(
  DriverChatInteractor.new,
);

/// The riblet's public entry widget — what `/trip/:id/chat` builds.
///
/// With voice at #45 (no masked bridge, will never dial), chat is the ONLY
/// pickup-coordination channel that exists. A driver outside the wrong door, at
/// a dark block of flats, with a rider who is not answering, has — without this
/// surface — literally nothing.
class DriverChatRiblet extends ConsumerWidget {
  /// Creates the chat riblet for [rideId].
  const DriverChatRiblet({required this.rideId, super.key});

  /// The ride whose thread this surface reads and writes.
  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      DriverChatView(rideId: rideId);
}
