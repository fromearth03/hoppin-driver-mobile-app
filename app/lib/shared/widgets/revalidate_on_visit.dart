import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fires [revalidate] once, right after a screen's first frame.
///
/// Screen controllers cache for the whole session, which is right while the
/// screen is open — but navigating away, changing something elsewhere, and
/// coming back showed the old answer until a manual pull-to-refresh. The
/// route table wraps every data screen in this: the cached data stays on
/// screen (no spinner flash) while a fresh read overtakes it.
/// Stale-while-revalidate — the pattern a push notification cannot cover,
/// because most of what changes (an appeal filed, a document uploaded)
/// changes on another screen of this same app.
class RevalidateOnVisit extends ConsumerStatefulWidget {
  final void Function(WidgetRef ref) revalidate;
  final Widget child;

  const RevalidateOnVisit({
    super.key,
    required this.revalidate,
    required this.child,
  });

  @override
  ConsumerState<RevalidateOnVisit> createState() => _RevalidateOnVisitState();
}

class _RevalidateOnVisitState extends ConsumerState<RevalidateOnVisit> {
  @override
  void initState() {
    super.initState();
    // Post-frame: the first build must not mutate providers mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.revalidate(ref);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The wiring most routes want: refresh the notifier only when the provider
/// already holds data. A screen's very first build fetches on its own — a
/// second identical request would double the cold-start traffic, and its
/// response racing the build's could land staler data last.
void revalidateIfLoaded(
  WidgetRef ref,
  ProviderListenable<AsyncValue<Object?>> provider,
  void Function() refresh,
) {
  if (ref.read(provider).hasValue) refresh();
}
