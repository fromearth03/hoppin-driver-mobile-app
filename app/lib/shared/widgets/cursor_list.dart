import 'package:flutter/material.dart';

import '../../core/theme/typography.dart';
import '../nav/app_shell.dart';

/// A list backed by cursor pagination.
///
/// Both the statement and trip history page the same way, so the load-more
/// mechanics — and the rule that a page in flight cannot be requested twice
/// — live in one place.
///
/// Pages arrive as the driver reaches them. Making them hunt for a "Load
/// more" button at the bottom of a history they are already scrolling
/// through is a tap that carries no decision: they have said what they want
/// by scrolling there. The button stays as the fallback for the frame before
/// the fetch starts, and for anyone driving the list by keyboard.
class CursorList<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext, T) itemBuilder;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;
  final Widget? emptyState;
  final Widget? header;
  final Future<void> Function()? onRefresh;

  /// Supplied by tests to drive the list; screens let it default.
  final ScrollController? scrollController;

  /// How close to the end counts as "arriving there". Roughly two rows, so
  /// the next page is usually in hand before the driver reaches the gap.
  final double loadMoreExtent;

  const CursorList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.onLoadMore,
    this.emptyState,
    this.header,
    this.onRefresh,
    this.scrollController,
    this.loadMoreExtent = 320,
  });

  @override
  State<CursorList<T>> createState() => _CursorListState<T>();
}

class _CursorListState<T> extends State<CursorList<T>> {
  ScrollController? _own;

  ScrollController get _controller =>
      widget.scrollController ?? (_own ??= ScrollController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  /// True from the moment a page is asked for until the list grows or the
  /// parent reports the fetch finished.
  ///
  /// One approach to the end raises several scroll notifications, and the
  /// parent cannot set `isLoadingMore` before the next of them arrives — so
  /// relying on that flag alone posted the same cursor three times and filled
  /// the list with duplicate rows. This latch is what makes one approach mean
  /// one request.
  bool _asked = false;

  @override
  void didUpdateWidget(CursorList<T> old) {
    super.didUpdateWidget(old);
    // A page landed (the list grew) or the fetch resolved: arm for the next
    // approach.
    if (widget.items.length != old.items.length ||
        (old.isLoadingMore && !widget.isLoadingMore)) {
      _asked = false;
    }
  }

  /// Asks for the next page when the end is near, and only then.
  void _maybeLoadMore() {
    if (_asked || !widget.hasMore || widget.isLoadingMore) return;
    final onLoadMore = widget.onLoadMore;
    if (onLoadMore == null) return;
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (!position.hasContentDimensions) return;
    if (position.extentAfter <= widget.loadMoreExtent) {
      _asked = true;
      onLoadMore();
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis == Axis.vertical) _maybeLoadMore();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final list = ListView.builder(
      controller: _controller,
      // Both users of this list live inside the shell, whose floating pill
      // would otherwise trap the last row beneath it.
      padding: const EdgeInsets.only(bottom: AppShell.bottomClearance),
      // header + items + footer
      itemCount: (widget.header == null ? 0 : 1) + widget.items.length + 1,
      itemBuilder: (context, index) {
        if (widget.header != null && index == 0) return widget.header!;
        final offset = widget.header == null ? 0 : 1;
        final i = index - offset;

        if (i < widget.items.length) {
          return widget.itemBuilder(context, widget.items[i]);
        }

        if (widget.items.isEmpty && widget.emptyState != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 64),
            child: widget.emptyState!,
          );
        }
        if (widget.isLoadingMore) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (widget.hasMore && widget.onLoadMore != null) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: TextButton(
                onPressed: widget.onLoadMore,
                child: const Text('Load more', style: AppText.body),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );

    final lazy = NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: list,
    );
    if (widget.onRefresh == null) return lazy;
    return RefreshIndicator(onRefresh: widget.onRefresh!, child: lazy);
  }
}
